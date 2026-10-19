// GameHub: a single Durable Object that is the authoritative server for all rooms.
// Every state change happens here, serialized by the Durable Object runtime, so
// races between two simultaneous submissions are impossible by construction.
import { DurableObject } from 'cloudflare:workers';
import {
  type Card,
  type RoundRecord,
  type Side,
  DEFAULT_ROUNDS,
  cardCounts,
  clampRounds,
  isCard,
  matchWinner,
  roundWinner,
  scoresOf,
} from '../../shared/game';
import type {
  AdminRoomView,
  ClientMessage,
  PlayerView,
  RoomStatus,
  ServerMessage,
  TeamInfo,
} from '../../shared/protocol';

export interface Env {
  GAME_HUB: DurableObjectNamespace<GameHub>;
  ADMIN_PASSWORD?: string;
}

interface Seat {
  name: string;
  token: string;
  side: Side | null;
}

interface Room {
  code: string;
  roundsTotal: number;
  autoStart: boolean;
  status: RoomStatus;
  currentRound: number;
  seats: Seat[];
  pending: Partial<Record<Side, Card>>; // SECRET: never serialized to any client
  history: RoundRecord[];
  createdAt: number;
  resetCount: number;
  anomalies: string[];
}

interface Attachment {
  role: 'none' | 'player' | 'admin';
  code?: string;
  token?: string; // seat token for players
  connectedAt: number;
  failedLogins: number;
}

const STALE_MS = 35_000; // a socket with no ping for this long is considered dead
const ADMIN_TOKEN_TTL_MS = 12 * 60 * 60 * 1000;
const MAX_FAILED_LOGINS = 5;
const MAX_NAME_LEN = 24;

const T = {
  nameInUse: 'Este nombre ya está en uso en esta sala',
  roomNotFound: 'No existe una sala con ese código',
  roomFull: 'La sala ya tiene dos equipos',
  badName: 'Escribe un nombre de equipo (máximo 24 caracteres)',
  notInRoom: 'No estás en ninguna sala',
  notPlaying: 'La partida no está en curso',
  alreadyChose: 'Ya elegiste una carta en esta ronda',
  wrongRound: 'Esa ronda ya terminó',
  badCard: 'Carta no válida',
  notAdmin: 'Acción solo permitida al administrador',
  badPassword: 'Contraseña incorrecta',
  tooManyAttempts: 'Demasiados intentos fallidos. Recarga la página para intentar de nuevo',
  noPassword: 'El servidor no tiene contraseña de administrador configurada',
  sessionExpired: 'La sesión de administrador expiró. Ingresa de nuevo',
  kicked: 'Tu equipo se conectó desde otra pestaña o dispositivo',
  seatsCleared: 'El administrador vació la sala',
  roomDeleted: 'El administrador eliminó la sala',
  cantChangeRounds: 'Solo se puede cambiar el número de rondas antes de empezar o después de reiniciar',
  needTwoTeams: 'Se necesitan dos equipos para iniciar',
  badMessage: 'Mensaje no válido',
  staleSeat: 'Esa sala fue vaciada o eliminada. Pulsa "Entrar" de nuevo para unirte',
};

function randomToken(bytes = 24): string {
  const a = new Uint8Array(bytes);
  crypto.getRandomValues(a);
  return Array.from(a, (b) => b.toString(16).padStart(2, '0')).join('');
}

/** Constant-time string comparison (avoids timing side channels on the password). */
function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  const n = Math.max(x.length, y.length);
  for (let i = 0; i < n; i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

function normName(name: string): string {
  return name.trim().replace(/\s+/g, ' ').toLocaleLowerCase('es');
}

export function formatCode(n: number): string {
  // J001 .. J999, J1000 .. J99999 (always 4 to 6 alphanumeric characters)
  return 'J' + String(n).padStart(3, '0');
}

export class GameHub extends DurableObject<Env> {
  private rooms = new Map<string, Room>();
  private adminTokens = new Map<string, number>(); // token -> expiry

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    // Heartbeats are answered without waking the object (hibernation friendly).
    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping', 'pong'));
    ctx.blockConcurrencyWhile(async () => {
      const stored = await ctx.storage.list<Room>({ prefix: 'room:' });
      for (const room of stored.values()) this.rooms.set(room.code, room);
      const tokens = (await ctx.storage.get<Record<string, number>>('adminTokens')) ?? {};
      const now = Date.now();
      for (const [k, exp] of Object.entries(tokens)) if (exp > now) this.adminTokens.set(k, exp);
    });
  }

  // ---------------------------------------------------------------- transport

  async fetch(request: Request): Promise<Response> {
    if (request.headers.get('Upgrade') !== 'websocket') {
      return new Response('Se esperaba WebSocket', { status: 426 });
    }
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server);
    const att: Attachment = { role: 'none', connectedAt: Date.now(), failedLogins: 0 };
    server.serializeAttachment(att);
    await this.ensureAlarm();
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    if (typeof raw !== 'string' || raw.length > 4096) return;
    if (raw === 'ping') {
      ws.send('pong');
      return;
    }
    let msg: ClientMessage;
    try {
      msg = JSON.parse(raw);
    } catch {
      return this.send(ws, { t: 'error', msg: T.badMessage });
    }
    try {
      await this.handle(ws, msg);
    } catch (err) {
      console.error('handler error', err);
      this.send(ws, { t: 'error', msg: T.badMessage });
    }
  }

  async webSocketClose(ws: WebSocket): Promise<void> {
    const att = this.att(ws);
    try {
      ws.close(1000, 'bye');
    } catch {
      /* already closed */
    }
    if (att.role === 'player' && att.code) this.broadcastRoom(att.code, ws);
  }

  async webSocketError(ws: WebSocket): Promise<void> {
    await this.webSocketClose(ws);
  }

  /** Periodic sweep: close sockets whose heartbeat stopped (network drop without close frame). */
  async alarm(): Promise<void> {
    const now = Date.now();
    const touched = new Set<string>();
    for (const ws of this.ctx.getWebSockets()) {
      if (!this.isAlive(ws, now)) {
        const att = this.att(ws);
        if (att.role === 'player' && att.code) touched.add(att.code);
        try {
          ws.close(4000, 'timeout');
        } catch {
          /* ignore */
        }
      }
    }
    for (const code of touched) this.broadcastRoom(code);
    await this.ensureAlarm();
  }

  private async ensureAlarm(): Promise<void> {
    if (this.ctx.getWebSockets().length === 0) return;
    const current = await this.ctx.storage.getAlarm();
    if (current == null) await this.ctx.storage.setAlarm(Date.now() + 20_000);
  }

  private att(ws: WebSocket): Attachment {
    return (ws.deserializeAttachment() as Attachment) ?? { role: 'none', connectedAt: 0, failedLogins: 0 };
  }

  private setAtt(ws: WebSocket, att: Attachment): void {
    ws.serializeAttachment(att);
  }

  private isAlive(ws: WebSocket, now = Date.now()): boolean {
    if (ws.readyState !== WebSocket.OPEN) return false;
    const last = this.ctx.getWebSocketAutoResponseTimestamp(ws)?.getTime() ?? 0;
    const att = this.att(ws);
    return now - Math.max(last, att.connectedAt) < STALE_MS;
  }

  private send(ws: WebSocket, msg: ServerMessage): void {
    try {
      ws.send(JSON.stringify(msg));
    } catch {
      /* socket gone */
    }
  }

  // ---------------------------------------------------------------- dispatch

  private async handle(ws: WebSocket, msg: ClientMessage): Promise<void> {
    if (!msg || typeof msg !== 'object' || typeof (msg as { t?: unknown }).t !== 'string') {
      return this.send(ws, { t: 'error', msg: T.badMessage });
    }
    // Any message proves the socket is alive.
    const a = this.att(ws);
    a.connectedAt = Date.now();
    this.setAtt(ws, a);

    switch (msg.t) {
      case 'join':
        return this.onJoin(ws, msg.code, msg.name, msg.token);
      case 'leave':
        return this.onLeave(ws);
      case 'play':
        return this.onPlay(ws, msg.card, msg.round);
      case 'admin_login':
        return this.onAdminLogin(ws, msg.password);
      case 'admin_auth':
        return this.onAdminAuth(ws, msg.adminToken);
      case 'admin_logout':
        return this.onAdminLogout(ws);
      default:
        if (msg.t.startsWith('admin_')) return this.onAdminAction(ws, msg);
        return this.send(ws, { t: 'error', msg: T.badMessage });
    }
  }

  // ---------------------------------------------------------------- players

  private seatSockets(code: string, token: string, except?: WebSocket): WebSocket[] {
    return this.ctx.getWebSockets().filter((ws) => {
      if (ws === except) return false;
      const a = this.att(ws);
      return a.role === 'player' && a.code === code && a.token === token;
    });
  }

  private seatOnline(code: string, token: string, except?: WebSocket): boolean {
    return this.seatSockets(code, token, except).some((ws) => this.isAlive(ws));
  }

  private async onJoin(ws: WebSocket, rawCode: unknown, rawName: unknown, token: unknown): Promise<void> {
    const code = String(rawCode ?? '').trim().toUpperCase();
    const name = String(rawName ?? '').trim().replace(/\s+/g, ' ');
    if (!name || name.length > MAX_NAME_LEN) return this.send(ws, { t: 'error', msg: T.badName });
    const room = this.rooms.get(code);
    if (!room) return this.send(ws, { t: 'error', msg: T.roomNotFound });

    // If this socket was seated elsewhere, detach it first.
    const prev = this.att(ws);
    const prevCode = prev.role === 'player' ? prev.code : undefined;

    let seat = room.seats.find((s) => normName(s.name) === normName(name));
    if (seat) {
      // Reconnection by code + name.
      const sameDevice = typeof token === 'string' && token.length > 0 && safeEqual(token, seat.token);
      if (!sameDevice && this.seatOnline(code, seat.token, ws)) {
        return this.send(ws, { t: 'error', msg: T.nameInUse });
      }
      // Restore the seat. Any older socket for this seat is replaced.
      for (const old of this.seatSockets(code, seat.token, ws)) {
        this.send(old, { t: 'kicked', msg: T.kicked });
        const oa = this.att(old);
        oa.role = 'none';
        oa.code = undefined;
        oa.token = undefined;
        this.setAtt(old, oa);
        try {
          old.close(4001, 'replaced');
        } catch {
          /* ignore */
        }
      }
      if (!sameDevice) {
        // Rotate the token so the previous device cannot silently come back.
        seat.token = randomToken();
      }
    } else {
      // A seat token with no matching seat means this device belonged to a room that was
      // deleted or emptied and the code was later reused: never drop it silently into the new room.
      if (typeof token === 'string' && token.length > 0) return this.send(ws, { t: 'error', msg: T.staleSeat });
      if (room.seats.length >= 2) return this.send(ws, { t: 'error', msg: T.roomFull });
      seat = { name, token: randomToken(), side: null };
      room.seats.push(seat);
      if (room.seats.length === 2) {
        // Virtual coin flip (per the source tutorial) decides who takes hearts (Red) and spades (Black).
        const flip = new Uint8Array(1);
        crypto.getRandomValues(flip);
        const firstIsRed = (flip[0] & 1) === 1;
        room.seats[0].side = firstIsRed ? 'red' : 'black';
        room.seats[1].side = firstIsRed ? 'black' : 'red';
        if (room.autoStart && room.status === 'waiting') {
          room.status = 'playing';
          room.currentRound = 1;
        }
      }
      await this.saveRoom(room);
    }
    await this.saveRoom(room);

    this.setAtt(ws, { ...this.att(ws), role: 'player', code, token: seat.token });
    this.send(ws, { t: 'joined', code, name: seat.name, token: seat.token });
    if (prevCode && prevCode !== code) this.broadcastRoom(prevCode);
    this.broadcastRoom(code);
  }

  private async onLeave(ws: WebSocket): Promise<void> {
    const a = this.att(ws);
    const code = a.role === 'player' ? a.code : undefined;
    this.setAtt(ws, { ...a, role: 'none', code: undefined, token: undefined });
    this.send(ws, { t: 'left' });
    if (code) this.broadcastRoom(code);
  }

  private async onPlay(ws: WebSocket, card: unknown, round: unknown): Promise<void> {
    const a = this.att(ws);
    if (a.role !== 'player' || !a.code) return this.send(ws, { t: 'error', msg: T.notInRoom });
    const room = this.rooms.get(a.code);
    if (!room) return this.send(ws, { t: 'error', msg: T.roomNotFound });
    const seat = room.seats.find((s) => s.token === a.token);
    if (!seat || !seat.side) return this.send(ws, { t: 'error', msg: T.notInRoom });
    if (room.status !== 'playing') return this.send(ws, { t: 'error', msg: T.notPlaying });
    if (!isCard(card)) return this.send(ws, { t: 'error', msg: T.badCard });
    if (Number(round) !== room.currentRound) {
      this.logAnomaly(room, `stale play from ${seat.side} for round ${round} (current ${room.currentRound})`);
      return this.send(ws, { t: 'error', msg: T.wrongRound });
    }
    if (room.pending[seat.side]) {
      this.logAnomaly(room, `double submission from ${seat.side} in round ${room.currentRound}`);
      return this.send(ws, { t: 'error', msg: T.alreadyChose });
    }

    room.pending[seat.side] = card;

    const red = room.pending.red;
    const black = room.pending.black;
    if (red && black) {
      // Both choices are in: resolve atomically and reveal to everyone.
      room.history.push({ round: room.currentRound, red, black, winner: roundWinner(red, black) });
      room.pending = {};
      if (room.history.length >= room.roundsTotal) {
        room.status = 'finished';
      } else {
        room.currentRound += 1;
      }
    }
    await this.saveRoom(room);
    this.broadcastRoom(room.code);
  }

  private logAnomaly(room: Room, text: string): void {
    const line = `${new Date().toISOString()} ${text}`;
    console.warn(`[${room.code}] ${line}`);
    room.anomalies = [...(room.anomalies ?? []), line].slice(-50);
  }

  // ---------------------------------------------------------------- admin

  private isAdmin(ws: WebSocket): boolean {
    return this.att(ws).role === 'admin';
  }

  private async onAdminLogin(ws: WebSocket, password: unknown): Promise<void> {
    const a = this.att(ws);
    if (a.failedLogins >= MAX_FAILED_LOGINS) {
      this.send(ws, { t: 'admin_denied', msg: T.tooManyAttempts });
      return;
    }
    const expected = this.env.ADMIN_PASSWORD;
    if (!expected) return this.send(ws, { t: 'admin_denied', msg: T.noPassword });
    if (typeof password !== 'string' || !safeEqual(password, expected)) {
      a.failedLogins += 1;
      this.setAtt(ws, a);
      return this.send(ws, { t: 'admin_denied', msg: T.badPassword });
    }
    const adminToken = randomToken(32);
    this.adminTokens.set(adminToken, Date.now() + ADMIN_TOKEN_TTL_MS);
    await this.saveAdminTokens();
    this.setAtt(ws, { ...a, role: 'admin', code: undefined, token: undefined });
    this.send(ws, { t: 'admin_ok', adminToken });
    this.sendAdminRooms(ws);
  }

  private async onAdminAuth(ws: WebSocket, adminToken: unknown): Promise<void> {
    const exp = typeof adminToken === 'string' ? this.adminTokens.get(adminToken) : undefined;
    if (!exp || exp < Date.now()) return this.send(ws, { t: 'admin_denied', msg: T.sessionExpired });
    this.setAtt(ws, { ...this.att(ws), role: 'admin', code: undefined, token: undefined });
    this.send(ws, { t: 'admin_ok', adminToken: adminToken as string });
    this.sendAdminRooms(ws);
  }

  private async onAdminLogout(ws: WebSocket): Promise<void> {
    this.setAtt(ws, { ...this.att(ws), role: 'none' });
  }

  private async onAdminAction(ws: WebSocket, msg: ClientMessage): Promise<void> {
    if (!this.isAdmin(ws)) return this.send(ws, { t: 'error', msg: T.notAdmin });
    switch (msg.t) {
      case 'admin_create': {
        // Smallest free number: after deleting rooms, codes are reused from J001 upwards.
        let n = 1;
        while (this.rooms.has(formatCode(n))) n++;
        const code = formatCode(n);
        const room: Room = {
          code,
          roundsTotal: clampRounds(msg.rounds ?? DEFAULT_ROUNDS),
          autoStart: msg.autoStart !== false,
          status: 'waiting',
          currentRound: 1,
          seats: [],
          pending: {},
          history: [],
          createdAt: Date.now(),
          resetCount: 0,
          anomalies: [],
        };
        this.rooms.set(code, room);
        await this.saveRoom(room);
        this.send(ws, { t: 'admin_created', code });
        break;
      }
      case 'admin_start': {
        const room = this.rooms.get(String(msg.code));
        if (!room) return this.send(ws, { t: 'error', msg: T.roomNotFound });
        if (room.seats.length < 2) return this.send(ws, { t: 'error', msg: T.needTwoTeams });
        if (room.status === 'waiting') {
          room.status = 'playing';
          room.currentRound = 1;
          await this.saveRoom(room);
          this.broadcastRoom(room.code);
        }
        break;
      }
      case 'admin_set_rounds': {
        const room = this.rooms.get(String(msg.code));
        if (!room) return this.send(ws, { t: 'error', msg: T.roomNotFound });
        if (room.history.length > 0 || Object.keys(room.pending).length > 0) {
          return this.send(ws, { t: 'error', msg: T.cantChangeRounds });
        }
        room.roundsTotal = clampRounds(msg.rounds);
        await this.saveRoom(room);
        this.broadcastRoom(room.code);
        break;
      }
      case 'admin_reset': {
        const room = this.rooms.get(String(msg.code));
        if (!room) return this.send(ws, { t: 'error', msg: T.roomNotFound });
        this.resetRoom(room);
        await this.saveRoom(room);
        this.broadcastRoom(room.code);
        break;
      }
      case 'admin_reset_all': {
        for (const room of this.rooms.values()) {
          this.resetRoom(room);
          await this.saveRoom(room);
        }
        for (const code of this.rooms.keys()) this.broadcastRoom(code, undefined, false);
        break;
      }
      case 'admin_clear_seats': {
        const room = this.rooms.get(String(msg.code));
        if (!room) return this.send(ws, { t: 'error', msg: T.roomNotFound });
        this.kickRoomPlayers(room.code, T.seatsCleared);
        room.seats = [];
        this.resetRoom(room);
        room.status = 'waiting';
        await this.saveRoom(room);
        break;
      }
      case 'admin_delete': {
        const code = String(msg.code);
        if (!this.rooms.has(code)) return this.send(ws, { t: 'error', msg: T.roomNotFound });
        this.kickRoomPlayers(code, T.roomDeleted);
        this.rooms.delete(code);
        await this.ctx.storage.delete(`room:${code}`);
        break;
      }
      case 'admin_delete_all': {
        for (const code of this.rooms.keys()) {
          this.kickRoomPlayers(code, T.roomDeleted);
          await this.ctx.storage.delete(`room:${code}`);
        }
        this.rooms.clear();
        break;
      }
      default:
        return this.send(ws, { t: 'error', msg: T.badMessage });
    }
    this.broadcastAdmins();
  }

  private resetRoom(room: Room): void {
    room.history = [];
    room.pending = {};
    room.currentRound = 1;
    room.resetCount = (room.resetCount ?? 0) + 1;
    room.status = room.seats.length === 2 && room.autoStart ? 'playing' : 'waiting';
  }

  private kickRoomPlayers(code: string, text: string): void {
    for (const ws of this.ctx.getWebSockets()) {
      const a = this.att(ws);
      if (a.role === 'player' && a.code === code) {
        this.send(ws, { t: 'kicked', msg: text });
        this.setAtt(ws, { ...a, role: 'none', code: undefined, token: undefined });
      }
    }
  }

  // ---------------------------------------------------------------- views

  private teamInfos(room: Room, except?: WebSocket): TeamInfo[] {
    return room.seats.map((s) => ({
      name: s.name,
      side: s.side,
      online: this.seatOnline(room.code, s.token, except),
      hasChosen: s.side ? Boolean(room.pending[s.side]) : false,
    }));
  }

  private common(room: Room, except?: WebSocket) {
    const finished = room.status === 'finished';
    return {
      code: room.code,
      roundsTotal: room.roundsTotal,
      status: room.status,
      currentRound: room.currentRound,
      teams: this.teamInfos(room, except),
      history: room.history,
      scores: scoresOf(room.history),
      counts: { red: cardCounts(room.history, 'red'), black: cardCounts(room.history, 'black') },
      winner: finished ? matchWinner(room.history) : null,
    };
  }

  /** The ONLY place a player's view is built. The opponent's pending card is never included. */
  private playerView(room: Room, seat: Seat, except?: WebSocket): PlayerView {
    return {
      ...this.common(room, except),
      you: {
        name: seat.name,
        side: seat.side,
        myCard: seat.side ? (room.pending[seat.side] ?? null) : null,
      },
      resetCount: room.resetCount ?? 0,
    };
  }

  private adminView(room: Room): AdminRoomView {
    return { ...this.common(room), autoStart: room.autoStart, createdAt: room.createdAt };
  }

  private broadcastRoom(code: string, except?: WebSocket, notifyAdmins = true): void {
    const room = this.rooms.get(code);
    if (room) {
      for (const ws of this.ctx.getWebSockets()) {
        if (ws === except) continue;
        const a = this.att(ws);
        if (a.role !== 'player' || a.code !== code) continue;
        const seat = room.seats.find((s) => s.token === a.token);
        if (seat) this.send(ws, { t: 'room', view: this.playerView(room, seat, except) });
      }
    }
    if (notifyAdmins) this.broadcastAdmins(except);
  }

  private adminRooms(except?: WebSocket): AdminRoomView[] {
    return [...this.rooms.values()]
      .sort((x, y) => x.createdAt - y.createdAt)
      .map((r) => ({ ...this.adminView(r), teams: this.teamInfos(r, except) }));
  }

  private sendAdminRooms(ws: WebSocket): void {
    this.send(ws, { t: 'admin_rooms', rooms: this.adminRooms() });
  }

  private broadcastAdmins(except?: WebSocket): void {
    const admins = this.ctx.getWebSockets().filter((ws) => ws !== except && this.isAdmin(ws));
    if (admins.length === 0) return;
    const rooms = this.adminRooms(except);
    for (const ws of admins) this.send(ws, { t: 'admin_rooms', rooms });
  }

  // ---------------------------------------------------------------- storage

  private async saveRoom(room: Room): Promise<void> {
    await this.ctx.storage.put(`room:${room.code}`, room);
  }

  private async saveAdminTokens(): Promise<void> {
    const now = Date.now();
    const obj: Record<string, number> = {};
    for (const [k, exp] of this.adminTokens) if (exp > now) obj[k] = exp;
    await this.ctx.storage.put('adminTokens', obj);
  }
}
