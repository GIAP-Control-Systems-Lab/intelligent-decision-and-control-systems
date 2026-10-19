// WebSocket message protocol shared by backend and frontend.
import type { Card, CardCounts, RoundRecord, Side } from './game';

export type RoomStatus = 'waiting' | 'playing' | 'finished';

/** Public info about a seated team. Never contains in-round choices. */
export interface TeamInfo {
  name: string;
  side: Side | null; // assigned by a virtual coin flip when both teams are present
  online: boolean;
  hasChosen: boolean; // only a boolean: the card itself is never sent to anyone else
}

/** What a player client receives. Built server-side per seat. */
export interface PlayerView {
  code: string;
  roundsTotal: number;
  status: RoomStatus;
  currentRound: number; // 1-based round currently being played
  teams: TeamInfo[]; // 0..2 entries
  history: RoundRecord[]; // only RESOLVED rounds
  scores: Record<Side, number>;
  counts: Record<Side, CardCounts>;
  winner: Side | 'tie' | null; // set when finished
  you: { name: string; side: Side | null; myCard: Card | null };
  resetCount: number;
}

/** What the admin receives for each room. Also never contains pending cards. */
export interface AdminRoomView {
  code: string;
  roundsTotal: number;
  autoStart: boolean;
  status: RoomStatus;
  currentRound: number;
  teams: TeamInfo[];
  history: RoundRecord[];
  scores: Record<Side, number>;
  counts: Record<Side, CardCounts>;
  winner: Side | 'tie' | null;
  createdAt: number;
}

export type ClientMessage =
  | { t: 'join'; code: string; name: string; token?: string }
  | { t: 'leave' }
  | { t: 'play'; card: Card; round: number }
  | { t: 'admin_login'; password: string }
  | { t: 'admin_auth'; adminToken: string }
  | { t: 'admin_logout' }
  | { t: 'admin_create'; rounds: number; autoStart: boolean }
  | { t: 'admin_start'; code: string }
  | { t: 'admin_set_rounds'; code: string; rounds: number }
  | { t: 'admin_reset'; code: string }
  | { t: 'admin_reset_all' }
  | { t: 'admin_clear_seats'; code: string }
  | { t: 'admin_delete'; code: string }
  | { t: 'admin_delete_all' };

export type ServerMessage =
  | { t: 'joined'; code: string; name: string; token: string }
  | { t: 'room'; view: PlayerView }
  | { t: 'left' }
  | { t: 'kicked'; msg: string }
  | { t: 'admin_ok'; adminToken: string }
  | { t: 'admin_denied'; msg: string }
  | { t: 'admin_rooms'; rooms: AdminRoomView[] }
  | { t: 'admin_created'; code: string }
  | { t: 'error'; msg: string };
