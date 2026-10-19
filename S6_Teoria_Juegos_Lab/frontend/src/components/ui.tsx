import type { ReactNode } from 'react';
import { CARDS, type Card, type CardCounts, type RoundRecord, type Side } from '../../../shared/game';
import type { RoomStatus, TeamInfo } from '../../../shared/protocol';
import type { ConnState } from '../net';

export const SIDE_LABEL: Record<Side, string> = { red: 'Rojo', black: 'Negro' };
export const SIDE_SUIT: Record<Side, string> = { red: '♥', black: '♠' };
export const STATUS_LABEL: Record<RoomStatus, string> = {
  waiting: 'Esperando equipos',
  playing: 'En juego',
  finished: 'Terminada',
};

export function sideText(side: Side | null | undefined): string {
  return side ? `${SIDE_LABEL[side]} ${SIDE_SUIT[side]}` : 'Color por sortear';
}

export function teamOf(teams: TeamInfo[], side: Side): TeamInfo | undefined {
  return teams.find((t) => t.side === side);
}

export function sideClass(side: Side | null | undefined): string {
  if (side === 'red') return 'text-rojo';
  if (side === 'black') return 'text-negro';
  return 'text-muted';
}

/** A playing card face. Used both as a button (selection) and as a display. */
export function PlayingCard({
  card,
  side,
  size = 'md',
  selected,
  onClick,
  disabled,
  hidden,
  testId,
}: {
  card: Card | null;
  side: Side | null;
  size?: 'sm' | 'md' | 'lg';
  selected?: boolean;
  onClick?: () => void;
  disabled?: boolean;
  hidden?: boolean;
  testId?: string;
}) {
  const dims =
    size === 'lg'
      ? 'w-24 h-34 text-5xl sm:w-28 sm:h-40'
      : size === 'sm'
        ? 'w-10 h-14 text-lg'
        : 'w-[4.5rem] h-[6.5rem] text-4xl sm:w-24 sm:h-34';
  const color = side === 'red' ? 'text-rojo' : 'text-negro';
  const suit = side ? SIDE_SUIT[side] : '';
  const base = `relative shrink-0 ${dims} rounded-xl border-2 bg-white font-bold flex flex-col items-center justify-center select-none shadow-sm`;
  const state = selected
    ? 'border-[#1d4ed8] ring-4 ring-[#1d4ed8]/30 -translate-y-1'
    : 'border-ink/80';
  const content = hidden ? (
    <span className="text-muted text-3xl" aria-hidden>
      ?
    </span>
  ) : (
    <>
      <span className={color}>{card}</span>
      {size !== 'sm' && <span className={`${color} text-xl leading-none`}>{suit}</span>}
    </>
  );
  if (!onClick) {
    return (
      <div className={`${base} ${state} reveal`} data-testid={testId} aria-label={hidden ? 'Carta oculta' : `Carta ${card}`}>
        {content}
      </div>
    );
  }
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-pressed={selected}
      aria-label={`Elegir carta ${card}`}
      data-testid={testId}
      className={`${base} ${state} transition hover:-translate-y-1 disabled:opacity-40 disabled:hover:translate-y-0 cursor-pointer disabled:cursor-not-allowed`}
    >
      {content}
    </button>
  );
}

export function ConnBadge({ state }: { state: ConnState }) {
  const map: Record<ConnState, [string, string]> = {
    open: ['Conectado', 'bg-ok'],
    connecting: ['Conectando...', 'bg-amber-500'],
    closed: ['Sin conexión, reintentando...', 'bg-rojo'],
  };
  const [text, dot] = map[state];
  return (
    <span className="inline-flex items-center gap-2 text-sm text-muted" role="status" aria-live="polite">
      <span className={`inline-block w-2.5 h-2.5 rounded-full ${dot}`} />
      {text}
    </span>
  );
}

export function Panel({ title, children, className = '' }: { title?: ReactNode; children: ReactNode; className?: string }) {
  return (
    <section className={`bg-white border border-line rounded-2xl p-4 sm:p-5 ${className}`}>
      {title && <h2 className="font-semibold text-lg mb-3">{title}</h2>}
      {children}
    </section>
  );
}

export function TeamCard({ team, score, highlight }: { team?: TeamInfo; score: number; highlight?: boolean }) {
  if (!team) {
    return (
      <div className="flex-1 rounded-2xl border-2 border-dashed border-line p-4 text-muted min-w-0">
        <p className="text-sm">Esperando equipo...</p>
      </div>
    );
  }
  const tone = team.side === 'red' ? 'border-rojo bg-rojo-soft' : team.side === 'black' ? 'border-negro bg-negro-soft' : 'border-line bg-white';
  return (
    <div className={`flex-1 rounded-2xl border-2 p-4 min-w-0 ${tone} ${highlight ? 'ring-4 ring-[#1d4ed8]/25' : ''}`}>
      <div className="flex items-center justify-between gap-2">
        <span className={`text-sm font-semibold uppercase tracking-wide ${sideClass(team.side)}`}>{sideText(team.side)}</span>
        <span className={`text-xs ${team.online ? 'text-ok' : 'text-rojo'}`}>{team.online ? '● en línea' : '● desconectado'}</span>
      </div>
      <p className="font-bold text-lg truncate" title={team.name}>
        {team.name}
      </p>
      <div className="flex items-end justify-between mt-1">
        <span className="text-4xl font-extrabold tabular-nums" data-testid={`score-${team.side ?? 'na'}`}>
          {score}
        </span>
        <span className="text-xs text-muted">{team.hasChosen ? 'ya eligió' : ''}</span>
      </div>
    </div>
  );
}

export function HistoryTable({ history, teams }: { history: RoundRecord[]; teams: TeamInfo[] }) {
  if (history.length === 0) return <p className="text-muted text-sm">Todavía no hay rondas jugadas.</p>;
  let red = 0;
  let black = 0;
  const redName = teamOf(teams, 'red')?.name ?? 'Rojo';
  const blackName = teamOf(teams, 'black')?.name ?? 'Negro';
  return (
    <div className="overflow-x-auto -mx-1">
      <table className="w-full text-sm border-collapse min-w-[18rem]" data-testid="history-table">
        <thead>
          <tr className="text-left text-muted border-b border-line">
            <th className="py-2 px-1 font-medium">Ronda</th>
            <th className="py-2 px-1 font-medium text-rojo">{SIDE_LABEL.red}</th>
            <th className="py-2 px-1 font-medium">{SIDE_LABEL.black}</th>
            <th className="py-2 px-1 font-medium">Ganador</th>
            <th className="py-2 px-1 font-medium text-right">Marcador</th>
          </tr>
        </thead>
        <tbody>
          {history.map((r) => {
            if (r.winner === 'red') red++;
            else black++;
            return (
              <tr key={r.round} className="border-b border-line/60">
                <td className="py-1.5 px-1 tabular-nums">{r.round}</td>
                <td className="py-1.5 px-1 font-bold text-rojo">{r.red}</td>
                <td className="py-1.5 px-1 font-bold">{r.black}</td>
                <td className={`py-1.5 px-1 font-semibold ${sideClass(r.winner)}`}>
                  {SIDE_LABEL[r.winner]}
                  <span className="hidden sm:inline"> ({r.winner === 'red' ? redName : blackName})</span>
                </td>
                <td className="py-1.5 px-1 text-right tabular-nums">
                  <span className="text-rojo">{red}</span> - {black}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

export function CountsTable({ counts, teams }: { counts: Record<Side, CardCounts>; teams: TeamInfo[] }) {
  return (
    <div className="overflow-x-auto -mx-1">
      <table className="w-full text-sm border-collapse min-w-[20rem]" data-testid="counts-table">
        <thead>
          <tr className="text-muted border-b border-line">
            <th className="py-2 px-1 text-left font-medium">Equipo</th>
            {CARDS.map((c) => (
              <th key={c} className="py-2 px-1 font-medium">
                {c}
              </th>
            ))}
            <th className="py-2 px-1 font-medium">Total</th>
          </tr>
        </thead>
        <tbody>
          {(['red', 'black'] as Side[]).map((side) => (
            <tr key={side} className="border-b border-line/60 text-center">
              <td className={`py-1.5 px-1 text-left font-semibold ${sideClass(side)}`}>
                {SIDE_LABEL[side]}: {teamOf(teams, side)?.name ?? '-'}
              </td>
              {CARDS.map((c) => (
                <td key={c} className="py-1.5 px-1 tabular-nums">
                  {counts[side][c]}
                </td>
              ))}
              <td className="py-1.5 px-1 tabular-nums font-semibold">{counts[side].total}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function RulesBox({ mySide, open = false }: { mySide?: Side | null; open?: boolean }) {
  return (
    <details className="bg-white border border-line rounded-2xl p-4 group" open={open}>
      <summary className="cursor-pointer font-semibold">Reglas del juego</summary>
      <div className="mt-3 text-sm space-y-3 leading-relaxed">
        <p>
          Cada ronda, ambos equipos eligen en secreto una carta entre <b>K, A, 2 y 3</b> (A vale 1; K no tiene valor numérico).
          Las cartas se revelan al mismo tiempo. El ganador de la ronda suma 1 punto; no hay empates por ronda.
        </p>
        <div className={`rounded-xl p-3 ${mySide === 'red' ? 'bg-rojo-soft ring-2 ring-rojo' : 'bg-paper'}`}>
          <p className="font-semibold text-rojo">Gana ROJO ♥ si...</p>
          <ul className="list-disc ml-5">
            <li>ambos eligen K, o</li>
            <li>ambos eligen números distintos.</li>
          </ul>
        </div>
        <div className={`rounded-xl p-3 ${mySide === 'black' ? 'bg-negro-soft ring-2 ring-negro' : 'bg-paper'}`}>
          <p className="font-semibold">Gana NEGRO ♠ si...</p>
          <ul className="list-disc ml-5">
            <li>solo uno de los dos elige K, o</li>
            <li>ambos eligen el mismo número.</li>
          </ul>
        </div>
      </div>
    </details>
  );
}

export function ErrorNote({ text }: { text: string | null }) {
  if (!text) return null;
  return (
    <p className="rounded-xl bg-rojo-soft border border-rojo/40 text-rojo px-3 py-2 text-sm" role="alert" data-testid="error">
      {text}
    </p>
  );
}

export function winnerText(winner: Side | 'tie' | null, teams: TeamInfo[]): string {
  if (!winner) return '';
  if (winner === 'tie') return 'Empate';
  const t = teamOf(teams, winner);
  return `Ganó ${t?.name ?? ''} (${SIDE_LABEL[winner]})`;
}
