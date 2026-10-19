// Worker entry point. Routes WebSocket connections to the single GameHub Durable Object.
import { GameHub, type Env } from './hub';

export { GameHub };

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === '/ws') {
      try {
        const id = env.GAME_HUB.idFromName('global');
        return await env.GAME_HUB.get(id).fetch(request);
      } catch (err) {
        // Make the real cause visible in the terminal instead of an opaque 500.
        console.error('[GameHub] error al abrir la conexión:', err instanceof Error ? `${err.name}: ${err.message}` : err);
        return new Response('Error interno del servidor del juego', { status: 500 });
      }
    }
    if (url.pathname === '/') {
      // Someone opened the server address in a browser: point them to the game page.
      const local = url.hostname === 'localhost' || url.hostname === '127.0.0.1' || /^\d+\.\d+\.\d+\.\d+$/.test(url.hostname);
      const target = local ? `http://${url.hostname}:5173/` : null;
      const body = `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Servidor del juego</title>
<body style="font-family:system-ui,sans-serif;max-width:36rem;margin:3rem auto;padding:0 1rem;line-height:1.5">
<h1>Servidor del juego de cartas: OK</h1>
<p>Esta es la dirección del <b>servidor</b>, no la del juego.</p>
${target ? `<p>Para jugar abra: <a href="${target}">${target}</a><br>Panel del profesor: <a href="${target}#/admin">${target}#/admin</a></p>` : '<p>Para jugar abra la página publicada en GitHub Pages.</p>'}
</body>`;
      return new Response(body, { headers: { 'content-type': 'text/html; charset=utf-8' } });
    }
    if (url.pathname === '/favicon.ico') return new Response(null, { status: 204 });
    if (url.pathname === '/health') {
      return new Response('Servidor del juego de cartas: OK', {
        headers: { 'content-type': 'text/plain; charset=utf-8', 'access-control-allow-origin': '*' },
      });
    }
    return new Response('No encontrado', { status: 404 });
  },
} satisfies ExportedHandler<Env>;
