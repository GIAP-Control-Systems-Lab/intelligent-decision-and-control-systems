# Juego de cartas Rojo vs Negro (Teoría de Juegos)

Aplicación web en vivo para jugar en clase el juego de cartas K, A, 2, 3 del tutorial *Card Game Tutorial* (Universidad de Tokio). Un administrador (el profesor) crea salas; en cada sala juegan dos equipos que eligen cartas en secreto, ronda a ronda, y al final ven el marcador, la frecuencia de cada carta y el historial completo.

## Reglas implementadas (sin modificaciones)

Cada ronda ambos equipos eligen en secreto una carta entre K, A, 2 y 3 (A vale 1; K no tiene valor numérico). Las cartas se revelan al mismo tiempo.

| Gana ROJO si... | Gana NEGRO si... |
|---|---|
| ambos eligen K | solo uno elige K |
| ambos eligen números distintos | ambos eligen el mismo número |

El ganador de la ronda suma 1 punto. Por defecto la partida dura 10 rondas (configurable entre 1 y 30 por sala). Al final gana quien tenga más puntos; si hay igualdad se muestra "Empate". Como en el tutorial, el color de cada equipo se decide con un lanzamiento de moneda (virtual) cuando llega el segundo equipo.

## Arquitectura

```
Navegadores (equipos y profesor)          Cloudflare (plan gratuito)
┌───────────────────────────┐   WebSocket   ┌──────────────────────────────┐
│ React + Vite + Tailwind   │ ────────────► │ Worker  →  Durable Object    │
│ (GitHub Pages, estático)  │ ◄──────────── │ "GameHub" (estado de todas   │
└───────────────────────────┘   vistas      │  las salas, SQLite interno)  │
                                filtradas   └──────────────────────────────┘
```

* **Frontend:** React 19 + Vite + TypeScript + TailwindCSS. Es un sitio estático que se publica en GitHub Pages. Rutas: `#/` (equipos) y `#/admin` (profesor).
* **Backend:** un Cloudflare Worker con un único Durable Object (`GameHub`) que es el servidor autoritativo de todas las salas. Toda jugada pasa por él, que la valida, la guarda y decide el ganador. El Durable Object procesa los mensajes de uno en uno, así que dos envíos simultáneos nunca se pisan.
* **Código compartido:** `shared/game.ts` contiene las reglas y `shared/protocol.ts` los tipos de los mensajes; los usan el servidor y el cliente.

### Por qué Cloudflare Workers + Durable Objects

Se evaluaron Firebase Realtime Database (plan Spark), Supabase Realtime y PartyKit.

* **Firebase Spark** no permite Cloud Functions sin tarjeta, así que el servidor no podría resolver las rondas; habría que montar un esquema de compromiso y revelación con reglas de seguridad, más frágil. Además el emulador local exige instalar Java.
* **Supabase** pausa los proyectos gratuitos tras días de inactividad y la lógica de servidor (Edge Functions) no mantiene conexiones en tiempo real con estado.
* **Cloudflare Workers Free** no pide tarjeta de crédito, permite Durable Objects con almacenamiento SQLite y WebSockets, y si algún día se superaran los límites diarios las operaciones simplemente fallan hasta el día siguiente: nunca se cobra. Para desarrollo local, `wrangler dev` simula todo en el computador sin cuenta ni Java.

Límites diarios del plan gratuito (más que suficientes para una clase): 100 000 solicitudes, 13 000 GB·s de cómputo de Durable Objects y 100 000 filas escritas en SQLite. Una partida de 10 rondas usa unas pocas decenas de solicitudes.

### Modelo anti trampa

* La carta elegida en la ronda actual se guarda **solo en el servidor** (`room.pending`).
* Cada cliente recibe una vista construida a su medida (`playerView`): incluye su propia carta pendiente y, del rival, solo un booleano `hasChosen`. La vista del administrador tampoco incluye cartas pendientes (por si se proyecta en clase).
* Las cartas aparecen en la red únicamente dentro de `history`, es decir, cuando la ronda ya se resolvió.
* Cada jugada lleva el número de ronda: un doble clic o un mensaje atrasado se rechaza y se registra como anomalía en el servidor.
* La contraseña del administrador vive como secreto del servidor (`ADMIN_PASSWORD`). Nunca se incluye en el código del navegador. Se compara en tiempo constante y cada conexión queda bloqueada tras 5 intentos fallidos.

### Reconexión

Al entrar, el servidor entrega un token de puesto que el navegador guarda. Si se recarga la página o se cae la red, la app vuelve a entrar sola. Desde otro dispositivo basta con escribir **el mismo código y el mismo nombre**: si el puesto está desconectado, se recupera con su color, marcador y jugada pendiente. Si el puesto sigue conectado, se responde "Este nombre ya está en uso en esta sala". El servidor detecta conexiones muertas con un latido cada 10 s (a los 35 s sin latido el puesto queda libre para reconectar).

## Estructura del repositorio

```
juego-cartas/
├── shared/                 Reglas del juego y tipos del protocolo (compartidos)
│   ├── game.ts
│   └── protocol.ts
├── backend/                Cloudflare Worker + Durable Object
│   ├── src/index.ts        Punto de entrada (ruta /ws)
│   ├── src/hub.ts          GameHub: salas, jugadas, admin, reconexión
│   ├── wrangler.toml
│   └── .dev.vars.example   Contraseña local del admin
├── frontend/               React + Vite + Tailwind
│   ├── src/pages/Player.tsx
│   ├── src/pages/Admin.tsx
│   ├── src/components/ui.tsx
│   └── src/net.ts          Conexión WebSocket con reconexión automática
├── tests/
│   ├── game.test.ts        Las 16 combinaciones de cartas (T6)
│   └── integration.mjs     Pruebas de protocolo T1 a T10 contra el servidor local
├── scripts/dev-backend.mjs  Arranca el servidor local (datos en la carpeta temporal del sistema)
├── .github/workflows/deploy-pages.yml
├── README.md
└── OPERATOR_MANUAL.md
```

## Ejecutar en local (sin ninguna cuenta)

Requisito: **Node.js 22 o superior** (https://nodejs.org, versión LTS). Para comprobarlo: `node -v`.

```bash
npm install
npm run dev
```

Esto levanta dos procesos:

* el servidor del juego en `http://localhost:8787` (simulado localmente por Wrangler),
* la página web en `http://localhost:5173`.

La primera vez se crea `backend/.dev.vars` con la contraseña local del administrador: **`profe-local`** (puede cambiarla editando ese archivo).

* Pantalla de los equipos: http://localhost:5173
* Panel del profesor: http://localhost:5173/#/admin

Para jugar desde celulares en la misma red WiFi, use la dirección "Network" que imprime Vite (por ejemplo `http://192.168.1.20:5173`). Si Windows pregunta, permita el acceso de Node.js a redes privadas.

### Pruebas

```bash
npm test                    # reglas: las 16 combinaciones (no necesita el servidor)
npm run test:integration    # con `npm run dev` corriendo en otra terminal
```

## Publicar en internet (GitHub Pages + Cloudflare)

Resumen (la guía paso a paso con cada clic está en `OPERATOR_MANUAL.md`, sección "Puesta en línea en 10 minutos"):

1. Crear una cuenta gratuita en Cloudflare (sin tarjeta).
2. `npx wrangler login` y `npm run deploy -w backend` para publicar el servidor. Se obtiene una dirección `https://juego-cartas-backend.<su-subdominio>.workers.dev`.
3. `npx wrangler secret put ADMIN_PASSWORD` (desde la carpeta `backend`) para definir la contraseña real del profesor.
4. Subir este repositorio a GitHub, crear la variable `VITE_WS_URL` con el valor `wss://juego-cartas-backend.<su-subdominio>.workers.dev/ws` y activar Pages con "GitHub Actions".
5. La página queda en `https://<usuario>.github.io/<repositorio>/`.

## Ingreso del administrador, salas y equipos

* **Administrador:** abrir `#/admin`, escribir la contraseña. La sesión dura 12 horas en esa pestaña.
* **Crear sala:** elegir rondas (por defecto 10) y pulsar "Crear sala". Se genera un código corto y consecutivo (`J001`, `J002`, ...). Si se borran salas, los códigos libres se reutilizan desde el menor.
* **Unirse:** cada equipo abre la página, escribe el código y un nombre de equipo, y pulsa "Entrar". Cuando llegan los dos, se sortea el color y empieza la partida.

## Costos

$0. Cloudflare Workers Free y GitHub Pages (repositorio público) no requieren tarjeta de crédito. Superar un límite diario del plan gratuito produce errores temporales, nunca cargos.
