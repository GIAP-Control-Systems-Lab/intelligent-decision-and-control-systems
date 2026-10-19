// T6: all 16 card pairs checked against the frozen truth table of section 2.
import { describe, expect, it } from 'vitest';
import { CARDS, type Card, cardCounts, matchWinner, roundWinner, scoresOf } from '../shared/game';

// Independent truth table written literally from the specification (not derived from the code).
const TRUTH: Record<string, 'red' | 'black'> = {
  'K,K': 'red', // (a) both K
  'K,A': 'black', 'K,2': 'black', 'K,3': 'black', // (c) only Red chose K
  'A,K': 'black', '2,K': 'black', '3,K': 'black', // (c) only Black chose K
  'A,A': 'black', '2,2': 'black', '3,3': 'black', // (d) same number
  'A,2': 'red', 'A,3': 'red', '2,A': 'red', '2,3': 'red', '3,A': 'red', '3,2': 'red', // (b) different numbers
};

describe('roundWinner (frozen rules)', () => {
  it('truth table covers exactly 16 pairs', () => {
    expect(Object.keys(TRUTH)).toHaveLength(16);
  });
  for (const r of CARDS) {
    for (const b of CARDS) {
      it(`Rojo ${r} vs Negro ${b} -> ${TRUTH[`${r},${b}`]}`, () => {
        expect(roundWinner(r as Card, b as Card)).toBe(TRUTH[`${r},${b}`]);
      });
    }
  }
  it('Red wins 7 of 16 pairs and Black 9 of 16', () => {
    const wins = Object.values(TRUTH);
    expect(wins.filter((w) => w === 'red')).toHaveLength(7);
    expect(wins.filter((w) => w === 'black')).toHaveLength(9);
  });
});

describe('scores and counts', () => {
  const history = [
    { round: 1, red: 'A' as Card, black: 'K' as Card, winner: 'black' as const },
    { round: 2, red: '3' as Card, black: 'A' as Card, winner: 'red' as const },
  ];
  it('matches the tutorial worksheet example (1 vs K, then 3 vs 1 -> 1-1)', () => {
    expect(scoresOf(history)).toEqual({ red: 1, black: 1 });
    expect(matchWinner(history)).toBe('tie');
  });
  it('counts each card per side', () => {
    expect(cardCounts(history, 'red')).toEqual({ K: 0, A: 1, '2': 0, '3': 1, total: 2 });
    expect(cardCounts(history, 'black')).toEqual({ K: 1, A: 1, '2': 0, '3': 0, total: 2 });
  });
});
