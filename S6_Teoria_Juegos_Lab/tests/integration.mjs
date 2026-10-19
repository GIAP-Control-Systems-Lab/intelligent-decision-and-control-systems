// End-to-end protocol tests against a running local server (`npm run dev` or `npm run dev -w backend`).
// Usage: node tests/integration.mjs [ws://localhost:8787/ws] [adminPassword]
// Covers T1, T2, T3, T4, T5, T6 (server side), T7, T8, T9, T10 plus red-team cases.

const URL_WS = process.argv[2] ?? 'ws://localhost:8787/ws';
const ADMIN_PASSWORD = process.argv[3] ?? 'profe-local';

const results = [];
function check(id, desc, cond, evidence = '') {
  results.push({ id, desc, ok: Boolean(cond), evidence });
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${id}  ${desc}${evidence ? `  [${evidence}]` : ''}`);
}

class Client {
  constructor(label) {
    this.label = label;
    this.msgs = [];
    this.waiters = [];
  }
  open() {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(URL_WS);
      this.ws.onopen = () => resolve(this);
      this.ws.onerror = (e) => reject(e);
      this.ws.onmessage = (ev) => {
        if (ev.data === 'pong') return;
        const m = JSON.parse(ev.data);
        this.msgs.push(m);
        this.waiters = this.waiters.filter((w) => {
          if (w.pred(m)) {
            w.resolve(m);
            return false;
          }
          return true;
        });
      };
    });
  }
  send(obj) {
    this.ws.send(JSON.stringify(obj));
  }
  /** Resolves with the most recent already-received message matching pred, or waits for one. */
  seenOrWait(pred, ms = 4000) {
    const hit = [...this.msgs].reverse().find(pred);
    return hit ? Promise.resolve(hit) : this.waitFor(pred, ms);
  }
  waitFor(pred, ms = 4000) {
    return new Promise((resolve, reject) => {
      const t = setTimeout(() => reject(new Error(`${this.label}: timeout waiting`)), ms);
      this.waiters.push({ pred, resolve: (m) => (clearTimeout(t), resolve(m)) });
    });
  }
  async request(obj, pred, ms) {
    const p = this.waitFor(pred, ms);
    this.send(obj);
    return p;
  }
  lastRoom() {
    return [...this.msgs].reverse().find((m) => m.t === 'room')?.view;
  }
  close() {
    this.ws.close();
  }
}

const TRUTH = {
  'K,K': 'red', 'K,A': 'black', 'K,2': 'black', 'K,3': 'black',
  'A,K': 'black', '2,K': 'black', '3,K': 'black',
  'A,A': 'black', '2,2': 'black', '3,3': 'black',
  'A,2': 'red', 'A,3': 'red', '2,A': 'red', '2,3': 'red', '3,A': 'red', '3,2': 'red',
};
const CARDS = ['K', 'A', '2', '3'];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const isRoom = (m) => m.t === 'room';

async function admin() {
  const a = await new Client('admin').open();
  await a.request({ t: 'admin_login', password: ADMIN_PASSWORD }, (m) => m.t === 'admin_ok');
  return a;
}

async function createRoom(adm, rounds = 10, autoStart = true) {
  const m = await adm.request({ t: 'admin_create', rounds, autoStart }, (x) => x.t === 'admin_created');
  return m.code;
}

async function seatTwo(code, n1 = 'Equipo Uno', n2 = 'Equipo Dos') {
  const a = await new Client(n1).open();
  const b = await new Client(n2).open();
  await a.request({ t: 'join', code, name: n1 }, (m) => m.t === 'joined');
  await b.request({ t: 'join', code, name: n2 }, (m) => m.t === 'joined');
  const va = await a.seenOrWait((m) => isRoom(m) && m.view.status === 'playing');
  const vb = await b.seenOrWait((m) => isRoom(m) && m.view.status === 'playing');
  const byName = { [n1]: a, [n2]: b };
  const red = byName[va.view.teams.find((t) => t.side === 'red').name];
  const black = byName[va.view.teams.find((t) => t.side === 'black').name];
  return { a, b, va: va.view, vb: vb.view, red, black };
}

async function playRound(red, black, cr, cb, round) {
  const pr = red.waitFor((m) => isRoom(m) && m.view.history.length >= round);
  const pb = black.waitFor((m) => isRoom(m) && m.view.history.length >= round);
  red.send({ t: 'play', card: cr, round });
  await sleep(15);
  black.send({ t: 'play', card: cb, round });
  return [(await pr).view, (await pb).view];
}

const EXPECTED_VIEW_KEYS = [
  'code', 'counts', 'currentRound', 'history', 'resetCount', 'roundsTotal', 'scores', 'status', 'teams', 'winner', 'you',
].join(',');

async function main() {
  // ---------------- T1
  const bad = await new Client('bad').open();
  const denied = await bad.request({ t: 'admin_login', password: 'clave-equivocada' }, (m) => m.t.startsWith('admin_'));
  check('T1', 'Contraseña incorrecta es rechazada', denied.t === 'admin_denied', denied.msg);
  const notAdmin = await bad.request({ t: 'admin_create', rounds: 10, autoStart: true }, (m) => m.t === 'error');
  check('T1', 'Acción admin sin login es rechazada', /administrador/.test(notAdmin.msg), notAdmin.msg);
  for (let i = 0; i < 5; i++) await bad.request({ t: 'admin_login', password: 'x' + i }, (m) => m.t === 'admin_denied');
  const locked = await bad.request({ t: 'admin_login', password: ADMIN_PASSWORD }, (m) => m.t.startsWith('admin_'));
  check('T1', 'Tras 5 intentos fallidos el socket queda bloqueado (anti fuerza bruta)', locked.t === 'admin_denied', locked.msg);
  bad.close();

  const adm = await admin();
  check('T1', 'Contraseña correcta es aceptada', true, 'admin_ok recibido');

  // ---------------- T2 (starts from an empty server: deletes every room first)
  await adm.request({ t: 'admin_delete_all' }, (m) => m.t === 'admin_rooms' && m.rooms.length === 0);
  const code = await createRoom(adm, 10);
  const list = await adm.waitFor((m) => m.t === 'admin_rooms' && m.rooms.some((r) => r.code === code));
  check('T2', 'Se crea la sala y aparece en la lista del admin', /^[A-Z0-9]{4,6}$/.test(code) && list, `código ${code}`);
  const code2 = await createRoom(adm, 10);
  check('T2', 'Códigos consecutivos desde J001 y sin colisión', code === 'J001' && code2 === 'J002', `${code} -> ${code2}`);
  const codeTmp = await createRoom(adm, 10); // J003
  await adm.request({ t: 'admin_delete', code: 'J002' }, (m) => m.t === 'admin_rooms' && !m.rooms.some((r) => r.code === 'J002'));
  await adm.request({ t: 'admin_delete', code: codeTmp }, (m) => m.t === 'admin_rooms' && !m.rooms.some((r) => r.code === codeTmp));
  const reused = await createRoom(adm, 10);
  check('T2', 'Al borrar salas, el siguiente código reutiliza el menor libre', reused === 'J002', `borradas J002 y J003 -> nueva ${reused}`);
  const staleC = await new Client('viejo-token').open();
  const staleErr = await staleC.request({ t: 'join', code: reused, name: 'Fantasma', token: 'token-de-sala-borrada' }, (m) => m.t === 'error' || m.t === 'joined');
  check('RT', 'Un dispositivo con puesto de una sala borrada no entra solo a la sala nueva con el mismo código', staleErr.t === 'error', staleErr.msg);
  staleC.close();

  // ---------------- T3
  const s = await seatTwo(code);
  const sides = s.va.teams.map((t) => t.side).sort().join(',');
  check('T3', 'Dos equipos con nombres distintos llegan a "listo" (partida iniciada)', s.va.status === 'playing' && s.vb.status === 'playing', `status=${s.va.status}`);
  check('T3', 'Lanzamiento de moneda asigna Rojo y Negro distintos', sides === 'black,red', sides);
  const third = await new Client('tercero').open();
  const full = await third.request({ t: 'join', code, name: 'Equipo Tres' }, (m) => m.t === 'error');
  check('RT', 'Un tercer equipo no puede entrar a la sala', /dos equipos/.test(full.msg), full.msg);
  const dupe = await third.request({ t: 'join', code, name: 'equipo uno' }, (m) => m.t === 'error');
  check('RT', 'Colisión de nombre con equipo conectado es rechazada', dupe.msg === 'Este nombre ya está en uso en esta sala', dupe.msg);
  third.close();

  // ---------------- T4 + T10 (secrecy)
  const blackMsgsBefore = s.black.msgs.length;
  const adminMsgsBefore = adm.msgs.length;
  const redAck = s.red.waitFor((m) => isRoom(m) && m.view.you.myCard === '3');
  const blackSeesChosen = s.black.waitFor((m) => isRoom(m) && m.view.teams.some((t) => t.side === 'red' && t.hasChosen));
  s.red.send({ t: 'play', card: '3', round: 1 });
  const ra = await redAck;
  const bs = await blackSeesChosen;
  check('T4', 'Rojo elige y su vista muestra la espera (myCard propio, sin historial nuevo)', ra.view.you.myCard === '3' && ra.view.history.length === 0);
  await sleep(150);
  const leaked = s.black.msgs.slice(blackMsgsBefore);
  const adminLeaked = adm.msgs.slice(adminMsgsBefore);
  const structuralOk = leaked.every((m) => {
    if (m.t !== 'room') return true;
    const v = m.view;
    return (
      Object.keys(v).sort().join(',') === EXPECTED_VIEW_KEYS &&
      v.you.myCard === null &&
      v.history.length === 0 &&
      v.teams.every((t) => Object.keys(t).sort().join(',') === 'hasChosen,name,online,side')
    );
  });
  const rawHasCard = leaked.some((m) => /:"3"/.test(JSON.stringify(m)));
  check('T4', 'Negro NO ve la carta de Rojo antes de elegir (solo un booleano hasChosen)', structuralOk && !rawHasCard && bs.view.you.myCard === null, `${leaked.length} mensajes inspeccionados`);
  const adminRaw = adminLeaked.some((m) => /:"3"/.test(JSON.stringify(m)));
  const detectorWorks = /:"3"/.test(JSON.stringify(ra)); // positive control: the owner's own message DOES contain it
  check('T10', 'Ningún mensaje de red (jugador rival ni admin) contiene la carta pendiente', detectorWorks && !rawHasCard && !adminRaw, `bytes rival=${JSON.stringify(leaked).length}, admin=${JSON.stringify(adminLeaked).length}`);
  const dbl = await s.red.request({ t: 'play', card: 'K', round: 1 }, (m) => m.t === 'error');
  check('RT', 'Doble envío en la misma ronda es rechazado', dbl.msg === 'Ya elegiste una carta en esta ronda', dbl.msg);

  // ---------------- T5
  const pr = s.red.waitFor((m) => isRoom(m) && m.view.history.length === 1);
  const pb = s.black.waitFor((m) => isRoom(m) && m.view.history.length === 1);
  s.black.send({ t: 'play', card: '3', round: 1 });
  const [r1, b1] = [(await pr).view, (await pb).view];
  const h = r1.history[0];
  check('T5', 'Ambos ven las dos cartas, el ganador y el marcador (3 vs 3 -> Negro)', h.red === '3' && h.black === '3' && h.winner === 'black' && b1.history[0].winner === 'black' && r1.scores.black === 1 && r1.scores.red === 0 && r1.currentRound === 2, JSON.stringify(h));
  const stale = await s.black.request({ t: 'play', card: 'A', round: 1 }, (m) => m.t === 'error');
  check('RT', 'Envío atrasado (ronda ya resuelta) es rechazado', stale.msg === 'Esa ronda ya terminó', stale.msg);

  // ---------------- T7: finish the 10-round match
  const seq = [['K', 'K'], ['A', '2'], ['2', 'K'], ['3', '1'.replace('1', 'A')], ['A', 'A'], ['K', '3'], ['2', '3'], ['3', '3'], ['A', 'K']];
  let lastR, lastB;
  for (let i = 0; i < seq.length; i++) [lastR, lastB] = await playRound(s.red, s.black, seq[i][0], seq[i][1], i + 2);
  const all = [['3', '3'], ...seq];
  const expScore = { red: 0, black: 0 };
  const cnt = { red: { K: 0, A: 0, 2: 0, 3: 0 }, black: { K: 0, A: 0, 2: 0, 3: 0 } };
  for (const [r, b] of all) {
    expScore[TRUTH[`${r},${b}`]]++;
    cnt.red[r]++;
    cnt.black[b]++;
  }
  const expWinner = expScore.red === expScore.black ? 'tie' : expScore.red > expScore.black ? 'red' : 'black';
  const countsOk = (v) => ['red', 'black'].every((sd) => CARDS.every((c) => v.counts[sd][c] === cnt[sd][c]) && v.counts[sd].total === 10);
  check('T7', 'Tras 10 rondas: estado final, marcador y ganador correctos en ambos clientes',
    lastR.status === 'finished' && lastB.status === 'finished' && lastR.scores.red === expScore.red && lastR.scores.black === expScore.black && lastR.winner === expWinner && lastB.winner === expWinner,
    `Rojo ${lastR.scores.red} - Negro ${lastR.scores.black}, ganador=${lastR.winner}`);
  check('T7', 'Tabla de frecuencias por carta y total = 10', countsOk(lastR) && countsOk(lastB), JSON.stringify(lastR.counts));
  check('T7', 'Historial completo de 10 rondas', lastR.history.length === 10 && lastR.history.every((x, i) => x.round === i + 1));
  await sleep(100);
  const admRoom = [...adm.msgs].reverse().find((m) => m.t === 'admin_rooms').rooms.find((r) => r.code === code);
  check('T7', 'La vista del admin muestra el mismo resultado', admRoom.status === 'finished' && admRoom.winner === expWinner && admRoom.history.length === 10 && countsOk(admRoom));
  const after = await s.red.request({ t: 'play', card: 'K', round: 11 }, (m) => m.t === 'error');
  check('RT', 'No se puede jugar después del final', after.msg === 'La partida no está en curso', after.msg);

  // ---------------- T6 server-side: all 16 pairs through the real server
  const code16 = await createRoom(adm, 16);
  const s16 = await seatTwo(code16, 'Alfa', 'Beta');
  let round = 0;
  let all16 = true;
  const wrong = [];
  for (const r of CARDS) {
    for (const b of CARDS) {
      round++;
      const [v] = await playRound(s16.red, s16.black, r, b, round);
      const rec = v.history[round - 1];
      if (rec.winner !== TRUTH[`${r},${b}`]) {
        all16 = false;
        wrong.push(`${r},${b}`);
      }
    }
  }
  check('T6', 'Las 16 combinaciones resueltas por el servidor coinciden con la tabla de verdad', all16, wrong.join(' ') || '16/16');

  // ---------------- T8 reconnection mid-round
  const code8 = await createRoom(adm, 10);
  const s8 = await seatTwo(code8, 'Gamma', 'Delta');
  await playRound(s8.red, s8.black, 'A', 'A', 1); // black 1 point
  const redName = s8.va.teams.find((t) => t.side === 'red').name;
  const redToken = s8.red.msgs.find((m) => m.t === 'joined').token;
  await s8.red.request({ t: 'play', card: '2', round: 2 }, (m) => isRoom(m) && m.view.you.myCard === '2');
  const offline = s8.black.waitFor((m) => isRoom(m) && m.view.teams.some((t) => t.name === redName && !t.online));
  s8.red.close(); // tab closed mid-round
  await offline;
  check('T8', 'El rival ve al equipo desconectado como "desconectado"', true);
  const back = await new Client('reabierto').open();
  // New tab, no token (worst case: different device): same code + same name.
  back.send({ t: 'join', code: code8.toLowerCase(), name: redName.toUpperCase() });
  const restored = await back.waitFor(isRoom);
  check('T8', 'Reabrir con mismo código y nombre restaura el puesto, el color, el marcador y la jugada pendiente',
    restored.view.you.side === 'red' && restored.view.scores.black === 1 && restored.view.you.myCard === '2' && restored.view.currentRound === 2,
    `side=${restored.view.you.side}, score=${JSON.stringify(restored.view.scores)}, myCard=${restored.view.you.myCard}`);
  const done = back.waitFor((m) => isRoom(m) && m.view.history.length === 2);
  s8.black.send({ t: 'play', card: '3', round: 2 });
  const d = await done;
  check('T8', 'La ronda continúa normalmente tras reconectar', d.view.history[1].red === '2' && d.view.history[1].winner === 'red');
  const oldDevice = await new Client('viejo').open();
  const rej = await oldDevice.request({ t: 'join', code: code8, name: redName, token: redToken }, (m) => m.t === 'error');
  check('RT', 'Un dispositivo antiguo no puede secuestrar el puesto mientras el nuevo está conectado', rej.msg === 'Este nombre ya está en uso en esta sala', rej.msg);
  oldDevice.close();
  // Same browser reload with its token: allowed even while the old socket is still open (it gets replaced).
  const newToken = back.msgs.find((m) => m.t === 'joined').token;
  const reload = await new Client('recarga').open();
  const kicked = back.waitFor((m) => m.t === 'kicked');
  await reload.request({ t: 'join', code: code8, name: redName, token: newToken }, (m) => m.t === 'joined');
  await kicked;
  check('T8', 'Recarga de la misma pestaña (con token) recupera el puesto y desplaza la conexión vieja', true);

  // ---------------- T9 resets
  const before9 = [...adm.msgs].reverse().find((m) => m.t === 'admin_rooms').rooms;
  const h16 = before9.find((r) => r.code === code16).history.length;
  const resetMsg = s.red.waitFor((m) => isRoom(m) && m.view.history.length === 0);
  const adm9 = adm.waitFor((m) => m.t === 'admin_rooms' && m.rooms.find((r) => r.code === code).history.length === 0);
  adm.send({ t: 'admin_reset', code });
  const [rv, am] = [await resetMsg, await adm9];
  const other = am.rooms.find((r) => r.code === code16);
  check('T9', 'Reinicio por sala limpia solo esa sala', rv.view.status === 'playing' && rv.view.scores.red === 0 && other.history.length === h16 && h16 === 16, `otra sala conserva ${other.history.length} rondas`);
  const admAll = adm.waitFor((m) => m.t === 'admin_rooms' && m.rooms.every((r) => r.history.length === 0));
  adm.send({ t: 'admin_reset_all' });
  const aa = await admAll;
  check('T9', 'Reinicio global limpia todas las salas', aa.rooms.every((r) => r.history.length === 0 && r.scores.red === 0 && r.scores.black === 0), `${aa.rooms.length} salas`);

  // ---------------- manual start fallback
  const codeM = await createRoom(adm, 5, false);
  const m1 = await new Client('m1').open();
  const m2 = await new Client('m2').open();
  await m1.request({ t: 'join', code: codeM, name: 'Uno' }, (m) => m.t === 'joined');
  await m2.request({ t: 'join', code: codeM, name: 'Dos' }, (m) => m.t === 'joined');
  await sleep(100);
  const waiting = m1.lastRoom().status === 'waiting';
  const started = m1.waitFor((m) => isRoom(m) && m.view.status === 'playing');
  adm.send({ t: 'admin_start', code: codeM });
  await started;
  check('RT', 'Inicio manual por el admin funciona cuando el inicio automático está apagado', waiting);

  for (const c of [s.a, s.b, s16.a, s16.b, s8.black, reload, m1, m2, adm]) c.close();

  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} verificaciones superadas`);
  process.exit(failed.length ? 1 : 0);
}

main().catch((e) => {
  console.error('ERROR', e);
  process.exit(1);
});
