// Canonical game rules (frozen specification, section 2). Do not modify.

export const CARDS = ['K', 'A', '2', '3'] as const;
export type Card = (typeof CARDS)[number];
export type Side = 'red' | 'black';

export const DEFAULT_ROUNDS = 10;
export const MIN_ROUNDS = 1;
export const MAX_ROUNDS = 30;

export function isCard(value: unknown): value is Card {
  return typeof value === 'string' && (CARDS as readonly string[]).includes(value);
}

/** Numeric value of a card. "K" has no numeric value. */
export function cardValue(card: Card): number | null {
  switch (card) {
    case 'A':
      return 1;
    case '2':
      return 2;
    case '3':
      return 3;
    default:
      return null;
  }
}

/**
 * Round winner for the revealed pair (cRed, cBlack).
 * RED wins if (a) both chose K, or (b) both numeric and different.
 * BLACK wins if (c) exactly one chose K, or (d) both numeric and equal.
 */
export function roundWinner(cRed: Card, cBlack: Card): Side {
  const redK = cRed === 'K';
  const blackK = cBlack === 'K';
  if (redK && blackK) return 'red'; // (a)
  if (redK !== blackK) return 'black'; // (c)
  return cardValue(cRed) !== cardValue(cBlack) ? 'red' : 'black'; // (b) / (d)
}

export interface RoundRecord {
  round: number;
  red: Card;
  black: Card;
  winner: Side;
}

export function scoresOf(history: RoundRecord[]): Record<Side, number> {
  const s = { red: 0, black: 0 };
  for (const r of history) s[r.winner] += 1;
  return s;
}

export type CardCounts = Record<Card, number> & { total: number };

export function cardCounts(history: RoundRecord[], side: Side): CardCounts {
  const c: CardCounts = { K: 0, A: 0, '2': 0, '3': 0, total: 0 };
  for (const r of history) {
    c[r[side]] += 1;
    c.total += 1;
  }
  return c;
}

export function matchWinner(history: RoundRecord[]): Side | 'tie' {
  const s = scoresOf(history);
  if (s.red === s.black) return 'tie';
  return s.red > s.black ? 'red' : 'black';
}

export function clampRounds(n: unknown): number {
  const v = Math.round(Number(n));
  if (!Number.isFinite(v)) return DEFAULT_ROUNDS;
  return Math.min(MAX_ROUNDS, Math.max(MIN_ROUNDS, v));
}
