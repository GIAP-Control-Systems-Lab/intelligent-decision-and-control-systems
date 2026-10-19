// Starts the local game server (wrangler dev).
// The Durable Object database is stored in a folder with a plain ASCII path (the system temp
// folder). On Windows, workerd cannot open its SQLite files when the project lives in a path
// with accents (for example "Decisión" or "TEORÍA"), which made every WebSocket fail with 500.
import { spawn } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const backendDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'backend');

const devVars = join(backendDir, '.dev.vars');
if (!existsSync(devVars)) {
  copyFileSync(join(backendDir, '.dev.vars.example'), devVars);
  console.log('[setup] Se creó backend/.dev.vars con la contraseña local de administrador: profe-local');
}

const stateDir = process.env.JUEGO_CARTAS_STATE ?? join(tmpdir(), 'juego-cartas-estado');
mkdirSync(stateDir, { recursive: true });
console.log(`[setup] Datos locales del servidor en: ${stateDir}`);

const require = createRequire(join(backendDir, 'package.json'));
const wranglerBin = join(dirname(require.resolve('wrangler/package.json')), 'bin', 'wrangler.js');
const child = spawn(process.execPath, [wranglerBin, 'dev', '--persist-to', stateDir, ...process.argv.slice(2)], {
  cwd: backendDir,
  stdio: 'inherit',
});
child.on('exit', (code) => process.exit(code ?? 0));
for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => child.kill(sig));
