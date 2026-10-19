// Single WebSocket connection with automatic reconnection and heartbeat.
import { useEffect, useRef, useState } from 'react';
import type { ClientMessage, ServerMessage } from '../../shared/protocol';

export type ConnState = 'connecting' | 'open' | 'closed';

function defaultUrl(): string {
  const fromEnv = import.meta.env.VITE_WS_URL as string | undefined;
  if (fromEnv) return fromEnv;
  // Local mode: backend runs on port 8787 of the same host (works on LAN too).
  const proto = location.protocol === 'https:' ? 'wss' : 'ws';
  return `${proto}://${location.hostname}:8787/ws`;
}

export const WS_URL = defaultUrl();

type Listener = (m: ServerMessage) => void;
type StateListener = (s: ConnState) => void;

class Connection {
  private ws: WebSocket | null = null;
  private listeners = new Set<Listener>();
  private stateListeners = new Set<StateListener>();
  private openHandlers = new Set<() => void>();
  private retry = 0;
  private pingTimer: number | undefined;
  private reconnectTimer: number | undefined;
  state: ConnState = 'connecting';

  connect(): void {
    if (this.ws && (this.ws.readyState === WebSocket.OPEN || this.ws.readyState === WebSocket.CONNECTING)) return;
    this.setState('connecting');
    const ws = new WebSocket(WS_URL);
    this.ws = ws;
    ws.onopen = () => {
      this.retry = 0;
      this.setState('open');
      window.clearInterval(this.pingTimer);
      this.pingTimer = window.setInterval(() => {
        if (ws.readyState === WebSocket.OPEN) ws.send('ping');
      }, 10_000);
      for (const h of this.openHandlers) h();
    };
    ws.onmessage = (ev) => {
      if (ev.data === 'pong') return;
      let msg: ServerMessage;
      try {
        msg = JSON.parse(ev.data as string);
      } catch {
        return;
      }
      for (const l of this.listeners) l(msg);
    };
    ws.onclose = () => {
      window.clearInterval(this.pingTimer);
      if (this.ws !== ws) return;
      this.setState('closed');
      const delay = Math.min(8000, 500 * 2 ** this.retry++);
      window.clearTimeout(this.reconnectTimer);
      this.reconnectTimer = window.setTimeout(() => this.connect(), delay);
    };
    ws.onerror = () => ws.close();
  }

  send(msg: ClientMessage): boolean {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(msg));
      return true;
    }
    return false;
  }

  private setState(s: ConnState) {
    this.state = s;
    for (const l of this.stateListeners) l(s);
  }

  onMessage(l: Listener) {
    this.listeners.add(l);
    return () => this.listeners.delete(l);
  }
  onState(l: StateListener) {
    this.stateListeners.add(l);
    return () => this.stateListeners.delete(l);
  }
  onOpen(h: () => void) {
    this.openHandlers.add(h);
    return () => this.openHandlers.delete(h);
  }
}

export const conn = new Connection();

/** Subscribes a component to the connection. `onOpen` runs on every (re)connection. */
export function useConnection(onMessage: Listener, onOpen: () => void): ConnState {
  const [state, setState] = useState<ConnState>(conn.state);
  const msgRef = useRef(onMessage);
  const openRef = useRef(onOpen);
  msgRef.current = onMessage;
  openRef.current = onOpen;

  useEffect(() => {
    const offMsg = conn.onMessage((m) => msgRef.current(m));
    const offState = conn.onState(setState);
    const offOpen = conn.onOpen(() => openRef.current());
    conn.connect();
    if (conn.state === 'open') openRef.current();
    setState(conn.state);
    return () => {
      offMsg();
      offState();
      offOpen();
    };
  }, []);
  return state;
}

// ------------------------------------------------------------- safe storage

export function loadJSON<T>(storage: 'local' | 'session', key: string): T | null {
  try {
    const s = storage === 'local' ? window.localStorage : window.sessionStorage;
    const raw = s.getItem(key);
    return raw ? (JSON.parse(raw) as T) : null;
  } catch {
    return null;
  }
}

export function saveJSON(storage: 'local' | 'session', key: string, value: unknown): void {
  try {
    const s = storage === 'local' ? window.localStorage : window.sessionStorage;
    if (value === null) s.removeItem(key);
    else s.setItem(key, JSON.stringify(value));
  } catch {
    /* storage unavailable: the app still works, only auto-rejoin is lost */
  }
}
