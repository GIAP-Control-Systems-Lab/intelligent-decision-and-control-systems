import { useCallback, useEffect, useRef, useState } from 'react';
import { CARDS, type Card } from '../../../shared/game';
import type { PlayerView, ServerMessage } from '../../../shared/protocol';
import {
  ConnBadge,
  CountsTable,
  ErrorNote,
  HistoryTable,
  Panel,
  PlayingCard,
  RulesBox,
  SIDE_LABEL,
  TeamCard,
  sideClass,
  sideText,
  teamOf,
  winnerText,
} from '../components/ui';
import { conn, loadJSON, saveJSON, useConnection } from '../net';

interface Session {
  code: string;
  name: string;
  token?: string;
}

const SESSION_KEY = 'juego-cartas-sesion';

export default function Player() {
  const [session, setSession] = useState<Session | null>(() => loadJSON<Session>('local', SESSION_KEY));
  const [view, setView] = useState<PlayerView | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [joining, setJoining] = useState(false);
  const sessionRef = useRef(session);
  sessionRef.current = session;
  const viewRef = useRef(view);
  viewRef.current = view;

  const persist = (s: Session | null) => {
    setSession(s);
    saveJSON('local', SESSION_KEY, s);
  };

  const onMessage = useCallback((m: ServerMessage) => {
    switch (m.t) {
      case 'joined':
        setJoining(false);
        setError(null);
        persist({ code: m.code, name: m.name, token: m.token });
        break;
      case 'room':
        setView(m.view);
        break;
      case 'kicked':
        setView(null);
        setError(m.msg);
        persist(sessionRef.current ? { code: sessionRef.current.code, name: sessionRef.current.name } : null);
        setJoining(false);
        setForceForm(true);
        break;
      case 'left':
        setView(null);
        break;
      case 'error':
        setJoining(false);
        setError(m.msg);
        // A failed (re)join leaves us outside any room: forget the stale seat token.
        if (!viewRef.current && sessionRef.current?.token) {
          persist({ code: sessionRef.current.code, name: sessionRef.current.name });
        }
        break;
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const [forceForm, setForceForm] = useState(false);

  // On every (re)connection, silently re-join the stored seat (reconnection requirement).
  const onOpen = useCallback(() => {
    const s = sessionRef.current;
    if (s?.token) {
      setJoining(true);
      conn.send({ t: 'join', code: s.code, name: s.name, token: s.token });
    }
  }, []);

  const state = useConnection(onMessage, onOpen);

  const join = (code: string, name: string) => {
    setError(null);
    setForceForm(false);
    const prev = sessionRef.current;
    const token = prev && prev.code === code.toUpperCase() && prev.name.toLowerCase() === name.toLowerCase() ? prev.token : undefined;
    sessionRef.current = { code, name, token };
    setJoining(true);
    if (!conn.send({ t: 'join', code, name, token })) {
      setJoining(false);
      setError('Sin conexión con el servidor. Reintentando...');
    }
  };

  const leave = () => {
    conn.send({ t: 'leave' });
    setView(null);
    // Keep code and name so the team can come back to the same seat later.
    persist(session ? { code: session.code, name: session.name } : null);
    setForceForm(true);
  };

  const showGame = view && !forceForm;

  return (
    <div className="max-w-3xl mx-auto px-4 py-5 sm:py-8 space-y-4">
      <header className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight">
          <span className="text-rojo">Rojo</span> vs Negro
        </h1>
        <ConnBadge state={state} />
      </header>

      {showGame ? (
        <Game view={view} error={error} onLeave={leave} clearError={() => setError(null)} />
      ) : (
        <JoinForm
          initial={session}
          busy={joining && state === 'open'}
          error={error}
          disabled={state !== 'open'}
          onJoin={join}
        />
      )}

      <footer className="pt-6 text-center text-sm text-muted">
        <a href="#/admin" className="underline">
          Acceso del profesor
        </a>
      </footer>
    </div>
  );
}

function JoinForm({
  initial,
  busy,
  error,
  disabled,
  onJoin,
}: {
  initial: Session | null;
  busy: boolean;
  error: string | null;
  disabled: boolean;
  onJoin: (code: string, name: string) => void;
}) {
  const [code, setCode] = useState(initial?.code ?? '');
  const [name, setName] = useState(initial?.name ?? '');
  useEffect(() => {
    if (initial) {
      setCode(initial.code);
      setName(initial.name);
    }
  }, [initial?.code, initial?.name]);

  return (
    <>
      <Panel title="Entrar a una sala">
        <form
          className="space-y-4"
          onSubmit={(e) => {
            e.preventDefault();
            if (code.trim() && name.trim()) onJoin(code.trim().toUpperCase(), name.trim());
          }}
        >
          <label className="block">
            <span className="text-sm font-medium">Código de la sala</span>
            <input
              className="mt-1 w-full rounded-xl border-2 border-line bg-paper px-3 py-3 text-2xl font-bold tracking-widest uppercase focus:border-ink outline-none"
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              placeholder="J001"
              maxLength={6}
              autoCapitalize="characters"
              autoComplete="off"
              inputMode="text"
              name="code"
              required
            />
          </label>
          <label className="block">
            <span className="text-sm font-medium">Nombre del equipo</span>
            <input
              className="mt-1 w-full rounded-xl border-2 border-line bg-paper px-3 py-3 text-lg focus:border-ink outline-none"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Ej.: Los Estrategas"
              maxLength={24}
              autoComplete="off"
              name="team"
              required
            />
            <span className="text-xs text-muted">
              Si se desconectan, vuelvan a entrar con el mismo código y el mismo nombre para recuperar su puesto.
            </span>
          </label>
          <ErrorNote text={error} />
          <button
            type="submit"
            disabled={disabled || busy}
            className="w-full rounded-xl bg-ink text-white font-semibold py-3 text-lg disabled:opacity-50"
          >
            {busy ? 'Entrando...' : 'Entrar'}
          </button>
        </form>
      </Panel>
      <RulesBox />
    </>
  );
}

function Game({
  view,
  error,
  onLeave,
  clearError,
}: {
  view: PlayerView;
  error: string | null;
  onLeave: () => void;
  clearError: () => void;
}) {
  const [selected, setSelected] = useState<Card | null>(null);
  const [sending, setSending] = useState(false);
  const me = view.you;
  const red = teamOf(view.teams, 'red');
  const black = teamOf(view.teams, 'black');
  const opponent = view.teams.find((t) => t.name !== me.name);
  const last = view.history[view.history.length - 1];

  // New round or reset: clear local selection.
  useEffect(() => {
    setSelected(null);
    setSending(false);
  }, [view.currentRound, view.resetCount, view.status]);
  useEffect(() => {
    if (me.myCard) setSending(false);
  }, [me.myCard]);

  const submit = () => {
    if (!selected || sending) return;
    clearError();
    setSending(true);
    if (!conn.send({ t: 'play', card: selected, round: view.currentRound })) setSending(false);
  };

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2 text-sm">
        <span>
          Sala <b className="tracking-widest" data-testid="room-code">{view.code}</b>
        </span>
        <span className="font-semibold" data-testid="round-label">
          {view.status === 'finished'
            ? `Partida terminada (${view.roundsTotal} rondas)`
            : view.status === 'playing'
              ? `Ronda ${view.currentRound} de ${view.roundsTotal}`
              : `${view.roundsTotal} rondas`}
        </span>
        <button type="button" onClick={onLeave} className="underline text-muted">
          Salir
        </button>
      </div>

      {me.side && (
        <p className={`rounded-2xl px-4 py-3 font-semibold ${me.side === 'red' ? 'bg-rojo text-white' : 'bg-negro text-white'}`} data-testid="my-side">
          Ustedes son el equipo {SIDE_LABEL[me.side].toUpperCase()} {me.side === 'red' ? '♥' : '♠'} ({me.name})
        </p>
      )}

      <div className="flex gap-3">
        {view.teams.length === 2 && red && black ? (
          <>
            <TeamCard team={red} score={view.scores.red} highlight={red.name === me.name} />
            <TeamCard team={black} score={view.scores.black} highlight={black.name === me.name} />
          </>
        ) : (
          <>
            <TeamCard team={view.teams[0]} score={0} highlight={view.teams[0]?.name === me.name} />
            <TeamCard team={view.teams[1]} score={0} highlight={view.teams[1]?.name === me.name} />
          </>
        )}
      </div>

      <ErrorNote text={error} />

      {view.status === 'waiting' && (
        <Panel>
          <p className="text-xl font-semibold text-center py-6" data-testid="status-msg">
            {view.teams.length < 2 ? 'Esperando al otro equipo...' : 'Esperando a que el profesor inicie la partida...'}
          </p>
          {view.teams.length < 2 && (
            <p className="text-center text-sm text-muted">
              Compartan el código <b>{view.code}</b> con el equipo rival. El color (Rojo o Negro) se sortea al llegar.
            </p>
          )}
        </Panel>
      )}

      {view.status === 'playing' && last && <LastRound view={view} />}

      {view.status === 'playing' && me.side && (
        <Panel title={`Ronda ${view.currentRound}: elijan su carta`}>
          {me.myCard ? (
            <div className="flex flex-col items-center gap-3 py-2">
              <div className="flex items-center gap-4">
                <div className="text-center">
                  <PlayingCard card={me.myCard} side={me.side} size="md" testId="my-played-card" />
                  <p className="text-xs mt-1 text-muted">Su carta</p>
                </div>
                <span className="text-muted font-semibold">vs</span>
                <div className="text-center">
                  <PlayingCard card={null} side={opponent?.side ?? null} hidden size="md" />
                  <p className="text-xs mt-1 text-muted">{opponent?.hasChosen ? 'Ya eligió' : 'Pensando...'}</p>
                </div>
              </div>
              <p className="text-lg font-semibold text-center" data-testid="status-msg">
                Esperando la jugada del otro equipo...
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              <div className="flex justify-center gap-2 sm:gap-4" role="group" aria-label="Cartas disponibles">
                {CARDS.map((c) => (
                  <PlayingCard
                    key={c}
                    card={c}
                    side={me.side}
                    selected={selected === c}
                    onClick={() => setSelected(c)}
                    disabled={sending}
                    testId={`card-${c}`}
                  />
                ))}
              </div>
              <button
                type="button"
                onClick={submit}
                disabled={!selected || sending}
                data-testid="confirm"
                className={`w-full rounded-xl font-semibold py-3 text-lg text-white disabled:opacity-40 ${me.side === 'red' ? 'bg-rojo' : 'bg-negro'}`}
              >
                {sending ? 'Enviando...' : selected ? `Jugar ${selected}` : 'Toquen una carta'}
              </button>
              <p className="text-xs text-muted text-center">La jugada es secreta: el otro equipo solo la verá cuando ambos hayan elegido.</p>
            </div>
          )}
        </Panel>
      )}

      {view.status === 'finished' && <FinalResult view={view} />}

      {view.status !== 'finished' && view.history.length > 0 && (
        <Panel title="Historial de rondas">
          <HistoryTable history={view.history} teams={view.teams} />
        </Panel>
      )}

      <RulesBox mySide={me.side} />
    </div>
  );
}

function LastRound({ view }: { view: PlayerView }) {
  const last = view.history[view.history.length - 1];
  const winTeam = teamOf(view.teams, last.winner);
  const iWon = last.winner === view.you.side;
  return (
    <Panel>
      <div className="flex flex-col sm:flex-row items-center gap-3 sm:gap-6" key={last.round} data-testid="last-round">
        <div className="flex items-center gap-3">
          <div className="text-center">
            <PlayingCard card={last.red} side="red" size="sm" />
            <p className="text-[11px] text-rojo mt-0.5">Rojo</p>
          </div>
          <div className="text-center">
            <PlayingCard card={last.black} side="black" size="sm" />
            <p className="text-[11px] mt-0.5">Negro</p>
          </div>
        </div>
        <p className="text-center sm:text-left">
          <span className="text-sm text-muted">Ronda {last.round}: </span>
          <b className={sideClass(last.winner)}>
            gana {SIDE_LABEL[last.winner]} ({winTeam?.name})
          </b>
          <span className="text-sm text-muted"> {iWon ? '+1 para ustedes' : '+1 para el rival'}</span>
        </p>
      </div>
    </Panel>
  );
}

function FinalResult({ view }: { view: PlayerView }) {
  const text = winnerText(view.winner, view.teams);
  const tone = view.winner === 'red' ? 'bg-rojo text-white' : view.winner === 'black' ? 'bg-negro text-white' : 'bg-white border-2 border-ink';
  return (
    <>
      <section className={`rounded-2xl p-5 text-center ${tone}`} data-testid="final-result">
        <p className="text-sm uppercase tracking-wide opacity-80">Resultado final</p>
        <p className="text-3xl font-extrabold mt-1" data-testid="winner">
          {text}
        </p>
        <p className="mt-2 text-lg tabular-nums">
          Rojo {view.scores.red} - {view.scores.black} Negro
        </p>
        {view.you.side && view.winner !== 'tie' && (
          <p className="mt-1 text-sm opacity-90">{view.winner === view.you.side ? '¡Felicitaciones!' : 'Buen intento. ¡A analizar la estrategia!'}</p>
        )}
      </section>
      <Panel title="Veces que se jugó cada carta">
        <CountsTable counts={view.counts} teams={view.teams} />
      </Panel>
      <Panel title="Historial completo">
        <HistoryTable history={view.history} teams={view.teams} />
      </Panel>
      <p className="text-center text-sm text-muted">
        Su puesto: {sideText(view.you.side)}. Para jugar otra partida, el profesor debe reiniciar la sala.
      </p>
    </>
  );
}
