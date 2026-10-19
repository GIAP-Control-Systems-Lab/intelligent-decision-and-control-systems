import { useCallback, useRef, useState } from 'react';
import { DEFAULT_ROUNDS, MAX_ROUNDS, MIN_ROUNDS } from '../../../shared/game';
import type { AdminRoomView, ClientMessage, ServerMessage } from '../../../shared/protocol';
import {
  ConnBadge,
  CountsTable,
  ErrorNote,
  HistoryTable,
  Panel,
  SIDE_LABEL,
  STATUS_LABEL,
  sideClass,
  sideText,
  winnerText,
} from '../components/ui';
import { conn, loadJSON, saveJSON, useConnection } from '../net';

const ADMIN_KEY = 'juego-cartas-admin';

export default function Admin() {
  const [token, setToken] = useState<string | null>(() => loadJSON<string>('session', ADMIN_KEY));
  const [authed, setAuthed] = useState(false);
  const [rooms, setRooms] = useState<AdminRoomView[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const tokenRef = useRef(token);
  tokenRef.current = token;

  const onMessage = useCallback((m: ServerMessage) => {
    switch (m.t) {
      case 'admin_ok':
        setAuthed(true);
        setError(null);
        setToken(m.adminToken);
        saveJSON('session', ADMIN_KEY, m.adminToken);
        break;
      case 'admin_denied':
        setAuthed(false);
        setError(m.msg);
        setToken(null);
        saveJSON('session', ADMIN_KEY, null);
        break;
      case 'admin_rooms':
        setRooms(m.rooms);
        break;
      case 'admin_created':
        setNotice(`Sala creada: ${m.code}. Compartan este código con los dos equipos.`);
        break;
      case 'error':
        setError(m.msg);
        break;
    }
  }, []);

  const onOpen = useCallback(() => {
    if (tokenRef.current) conn.send({ t: 'admin_auth', adminToken: tokenRef.current });
  }, []);

  const state = useConnection(onMessage, onOpen);

  const act = (msg: ClientMessage, confirmText?: string) => {
    if (confirmText && !window.confirm(confirmText)) return;
    setError(null);
    setNotice(null);
    conn.send(msg);
  };

  const logout = () => {
    conn.send({ t: 'admin_logout' });
    saveJSON('session', ADMIN_KEY, null);
    setToken(null);
    setAuthed(false);
    setRooms([]);
  };

  return (
    <div className="max-w-5xl mx-auto px-4 py-5 sm:py-8 space-y-4">
      <header className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight">Panel del profesor</h1>
        <div className="flex items-center gap-4">
          <ConnBadge state={state} />
          {authed && (
            <button type="button" className="underline text-sm" onClick={logout}>
              Cerrar sesión
            </button>
          )}
        </div>
      </header>

      {!authed ? (
        <Login disabled={state !== 'open'} error={error} onLogin={(password) => act({ t: 'admin_login', password })} />
      ) : (
        <>
          <Toolbar rooms={rooms} act={act} />
          <ErrorNote text={error} />
          {notice && (
            <p className="rounded-xl bg-white border border-ok/40 text-ok px-3 py-2 text-sm" role="status" data-testid="notice">
              {notice}
            </p>
          )}
          {rooms.length === 0 ? (
            <Panel>
              <p className="text-muted">Todavía no hay salas. Cree una con el botón de arriba.</p>
            </Panel>
          ) : (
            <div className="grid gap-4 md:grid-cols-2" data-testid="room-list">
              {rooms.map((r) => (
                <RoomCard key={r.code} room={r} act={act} />
              ))}
            </div>
          )}
        </>
      )}

      <footer className="pt-6 text-center text-sm text-muted">
        <a href="#/" className="underline">
          Ir a la pantalla de los equipos
        </a>
      </footer>
    </div>
  );
}

function Login({ disabled, error, onLogin }: { disabled: boolean; error: string | null; onLogin: (p: string) => void }) {
  const [password, setPassword] = useState('');
  return (
    <Panel title="Ingreso del administrador">
      <form
        className="space-y-3 max-w-sm"
        onSubmit={(e) => {
          e.preventDefault();
          if (password) onLogin(password);
        }}
      >
        <label className="block">
          <span className="text-sm font-medium">Contraseña</span>
          <input
            type="password"
            className="mt-1 w-full rounded-xl border-2 border-line bg-paper px-3 py-3 text-lg focus:border-ink outline-none"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            name="password"
            required
          />
        </label>
        <ErrorNote text={error} />
        <button type="submit" disabled={disabled} className="rounded-xl bg-ink text-white font-semibold px-5 py-3 disabled:opacity-50">
          Ingresar
        </button>
      </form>
    </Panel>
  );
}

function Toolbar({ rooms, act }: { rooms: AdminRoomView[]; act: (m: ClientMessage, c?: string) => void }) {
  const [rounds, setRounds] = useState(DEFAULT_ROUNDS);
  const [autoStart, setAutoStart] = useState(true);
  return (
    <Panel>
      <div className="flex flex-wrap items-end gap-3">
        <label className="block">
          <span className="text-sm font-medium">Rondas por partida</span>
          <input
            type="number"
            min={MIN_ROUNDS}
            max={MAX_ROUNDS}
            value={rounds}
            onChange={(e) => setRounds(Number(e.target.value))}
            className="mt-1 w-24 rounded-xl border-2 border-line bg-paper px-3 py-2 text-lg"
            name="rounds"
          />
        </label>
        <label className="flex items-center gap-2 pb-2.5 text-sm">
          <input type="checkbox" checked={autoStart} onChange={(e) => setAutoStart(e.target.checked)} className="w-5 h-5" />
          Inicio automático
        </label>
        <button
          type="button"
          className="rounded-xl bg-ink text-white font-semibold px-5 py-2.5"
          onClick={() => act({ t: 'admin_create', rounds, autoStart })}
          data-testid="create-room"
        >
          Crear sala
        </button>
        <div className="flex flex-wrap gap-2 ml-auto">
          <button type="button" className="rounded-xl border-2 border-ink px-4 py-2 text-sm font-semibold" onClick={() => downloadCsv(rooms)} disabled={rooms.length === 0}>
            Descargar resultados (CSV)
          </button>
          <button
            type="button"
            className="rounded-xl border-2 border-rojo text-rojo px-4 py-2 text-sm font-semibold"
            onClick={() => act({ t: 'admin_reset_all' }, '¿Reiniciar marcadores e historiales de TODAS las salas?')}
            data-testid="reset-all"
          >
            Reiniciar todas
          </button>
          <button
            type="button"
            className="rounded-xl bg-rojo text-white px-4 py-2 text-sm font-semibold"
            onClick={() => act({ t: 'admin_delete_all' }, '¿Eliminar TODAS las salas? Esta acción no se puede deshacer.')}
          >
            Eliminar todas
          </button>
        </div>
      </div>
      <p className="text-xs text-muted mt-2">
        Entre {MIN_ROUNDS} y {MAX_ROUNDS} rondas (por defecto {DEFAULT_ROUNDS}). Con inicio automático, la partida empieza apenas entran los dos equipos.
      </p>
    </Panel>
  );
}

function RoomCard({ room, act }: { room: AdminRoomView; act: (m: ClientMessage, c?: string) => void }) {
  const [open, setOpen] = useState(false);
  const [rounds, setRounds] = useState(room.roundsTotal);
  const canChangeRounds = room.history.length === 0 && !room.teams.some((t) => t.hasChosen);
  const badge =
    room.status === 'playing' ? 'bg-ok text-white' : room.status === 'finished' ? 'bg-ink text-white' : 'bg-amber-100 text-amber-900';
  return (
    <section className="bg-white border border-line rounded-2xl p-4 space-y-3" data-testid={`room-${room.code}`}>
      <div className="flex items-center justify-between gap-2">
        <span className="text-3xl font-extrabold tracking-widest">{room.code}</span>
        <span className={`text-xs font-semibold rounded-full px-3 py-1 ${badge}`}>{STATUS_LABEL[room.status]}</span>
      </div>

      <div className="grid grid-cols-2 gap-2 text-sm">
        {[0, 1].map((i) => {
          const t = room.teams[i];
          return (
            <div key={i} className="rounded-xl bg-paper p-2 min-w-0">
              {t ? (
                <>
                  <p className={`font-semibold ${sideClass(t.side)}`}>{sideText(t.side)}</p>
                  <p className="font-bold truncate" title={t.name}>
                    {t.name}
                  </p>
                  <p className="text-xs">
                    <span className={t.online ? 'text-ok' : 'text-rojo'}>{t.online ? 'en línea' : 'desconectado'}</span>
                    {room.status === 'playing' && <span className="text-muted">{t.hasChosen ? ' · ya eligió' : ' · eligiendo'}</span>}
                  </p>
                  {t.side && <p className="text-2xl font-extrabold tabular-nums">{room.scores[t.side]}</p>}
                </>
              ) : (
                <p className="text-muted">Esperando equipo...</p>
              )}
            </div>
          );
        })}
      </div>

      <p className="text-sm">
        {room.status === 'finished' ? (
          <b data-testid={`winner-${room.code}`}>
            {winnerText(room.winner, room.teams)} · Rojo {room.scores.red} - {room.scores.black} Negro
          </b>
        ) : room.status === 'playing' ? (
          <>
            Ronda <b>{room.currentRound}</b> de {room.roundsTotal}
          </>
        ) : (
          <>
            {room.roundsTotal} rondas · {room.autoStart ? 'inicio automático' : 'inicio manual'}
          </>
        )}
      </p>

      <div className="flex flex-wrap gap-2 text-sm">
        {room.status === 'waiting' && room.teams.length === 2 && (
          <button type="button" className="rounded-lg bg-ok text-white px-3 py-1.5 font-semibold" onClick={() => act({ t: 'admin_start', code: room.code })}>
            Iniciar partida
          </button>
        )}
        <button
          type="button"
          className="rounded-lg border-2 border-ink px-3 py-1.5 font-semibold"
          onClick={() => act({ t: 'admin_reset', code: room.code }, `¿Reiniciar marcador e historial de la sala ${room.code}?`)}
          data-testid={`reset-${room.code}`}
        >
          Reiniciar
        </button>
        <button
          type="button"
          className="rounded-lg border-2 border-line px-3 py-1.5"
          onClick={() => act({ t: 'admin_clear_seats', code: room.code }, `¿Sacar a los equipos de la sala ${room.code}? Podrán entrar equipos nuevos.`)}
        >
          Vaciar sala
        </button>
        <button
          type="button"
          className="rounded-lg border-2 border-rojo text-rojo px-3 py-1.5"
          onClick={() => act({ t: 'admin_delete', code: room.code }, `¿Eliminar la sala ${room.code}?`)}
        >
          Eliminar
        </button>
        <button type="button" className="rounded-lg px-3 py-1.5 underline ml-auto" onClick={() => setOpen((o) => !o)} aria-expanded={open}>
          {open ? 'Ocultar detalle' : 'Ver detalle'}
        </button>
      </div>

      {canChangeRounds && (
        <div className="flex items-center gap-2 text-sm">
          <label className="flex items-center gap-2">
            Rondas:
            <input
              type="number"
              min={MIN_ROUNDS}
              max={MAX_ROUNDS}
              value={rounds}
              onChange={(e) => setRounds(Number(e.target.value))}
              className="w-20 rounded-lg border-2 border-line bg-paper px-2 py-1"
            />
          </label>
          <button
            type="button"
            className="rounded-lg border-2 border-line px-3 py-1"
            disabled={rounds === room.roundsTotal}
            onClick={() => act({ t: 'admin_set_rounds', code: room.code, rounds })}
          >
            Guardar
          </button>
        </div>
      )}

      {open && (
        <div className="space-y-3 pt-2 border-t border-line">
          <h3 className="font-semibold text-sm">Veces que se jugó cada carta</h3>
          <CountsTable counts={room.counts} teams={room.teams} />
          <h3 className="font-semibold text-sm">Historial</h3>
          <HistoryTable history={room.history} teams={room.teams} />
        </div>
      )}
    </section>
  );
}

function downloadCsv(rooms: AdminRoomView[]) {
  const esc = (v: string | number) => `"${String(v).replace(/"/g, '""')}"`;
  const lines = [['Sala', 'Ronda', 'Equipo Rojo', 'Carta Rojo', 'Equipo Negro', 'Carta Negro', 'Ganador de la ronda', 'Ganador de la partida'].map(esc).join(';')];
  for (const r of rooms) {
    const red = r.teams.find((t) => t.side === 'red')?.name ?? '';
    const black = r.teams.find((t) => t.side === 'black')?.name ?? '';
    const final = r.winner ? winnerText(r.winner, r.teams) : 'En curso';
    for (const h of r.history) {
      lines.push([r.code, h.round, red, h.red, black, h.black, SIDE_LABEL[h.winner], final].map(esc).join(';'));
    }
  }
  const blob = new Blob(['﻿' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `resultados-juego-cartas-${new Date().toISOString().slice(0, 10)}.csv`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
