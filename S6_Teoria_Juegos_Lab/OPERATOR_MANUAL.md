# Manual del operador (profesor)

Este manual cubre el uso en clase y la puesta en línea. No se necesita saber programar.

## 1. Flujo de una sesión de clase

1. **Abrir el panel.** Entre a la dirección de la app agregando `#/admin` al final (en local: http://localhost:5173/#/admin). Escriba la contraseña de administrador y pulse **Ingresar**.
2. **Crear las salas.** Deje "Rondas por partida" en 10 (o el número que quiera, de 1 a 30) y pulse **Crear sala** una vez por cada pareja de equipos. Cada sala recibe un código: `J001`, `J002`, `J003`... Si borra salas, al crear nuevas se reutilizan los códigos libres empezando por el menor (después de "Eliminar todas" se vuelve a `J001`).
   * Con **Inicio automático** marcado, la partida arranca sola cuando entran los dos equipos.
   * Si lo desmarca, aparecerá el botón **Iniciar partida** en la sala cuando estén los dos equipos.
3. **Compartir los códigos.** Escriba en el tablero o envíe por WhatsApp algo como: "Pareja 1: sala J001. Pareja 2: sala J002..." junto con la dirección de la página.
4. **Los equipos entran.** Cada equipo abre la página en un celular o computador, escribe el código de su sala y un nombre de equipo, y pulsa **Entrar**.
   * El primero verá "Esperando al otro equipo...".
   * Cuando llega el segundo, la app lanza una moneda virtual: un equipo queda ROJO ♥ y el otro NEGRO ♠ (igual que en el tutorial).
5. **Juego.** En cada ronda cada equipo toca una carta y pulsa **Jugar**. Mientras el rival no elige, verán "Esperando la jugada del otro equipo...". Cuando ambos eligieron, las dos pantallas muestran las cartas, el ganador de la ronda y el marcador.
6. **Seguimiento.** En el panel ve, por sala: equipos, color, si están en línea, si ya eligieron (nunca qué carta), ronda actual y marcador. Puede proyectar el panel sin revelar jugadas en curso.
7. **Final.** Tras la última ronda, ambos equipos y el panel muestran el ganador (o "Empate"), la tabla de veces que se jugó cada carta (K, A, 2, 3 y total) y el historial completo. En el panel pulse **Ver detalle** en cada sala. El botón **Descargar resultados (CSV)** baja todas las rondas de todas las salas en un archivo que abre Excel, útil para la encuesta "Card Game Result Survey".
8. **Nueva partida o nueva clase.**
   * **Reiniciar** (en una sala): borra marcador e historial de esa sala; los mismos equipos vuelven a jugar desde la ronda 1.
   * **Reiniciar todas**: lo mismo para todas las salas a la vez.
   * **Vaciar sala**: saca a los equipos para que entren otros.
   * **Eliminar** / **Eliminar todas**: borra salas.
   * Mientras una sala no tenga rondas jugadas, puede cambiar su número de rondas y pulsar **Guardar**.

### Si un equipo se desconecta

Cerró la pestaña, se le apagó el celular o se cayó el WiFi: que vuelva a abrir la página y escriba **el mismo código y el mismo nombre de equipo**. Recupera su color, su marcador y, si ya había elegido carta en la ronda en curso, esa jugada. Si recarga la página en el mismo navegador, vuelve a entrar solo.

Si aparece "Este nombre ya está en uso en esta sala" es porque ese puesto sigue conectado en otro dispositivo. Ciérrelo allí, o espere unos 35 segundos a que el servidor detecte que esa conexión murió, y vuelva a intentar.

### Mensajes que pueden ver los equipos

| Mensaje | Qué significa |
|---|---|
| No existe una sala con ese código | Código mal escrito o la sala fue eliminada |
| La sala ya tiene dos equipos | Ya entraron dos equipos con otros nombres |
| Este nombre ya está en uso en esta sala | Ese equipo está conectado en otro dispositivo |
| Ya elegiste una carta en esta ronda | Se intentó jugar dos veces (doble toque); se ignora |
| Esperando a que el profesor inicie la partida... | La sala tiene inicio manual: pulse **Iniciar partida** |

## 2. Uso local en el aula (sin internet hacia afuera)

Si todos están en el mismo WiFi, puede correr la app en su portátil:

1. Instale Node.js 22 LTS desde https://nodejs.org (botón "LTS", instalar con opciones por defecto).
2. Abra una terminal en la carpeta del proyecto y ejecute `npm install` (solo la primera vez) y luego `npm run dev`.
3. Vite muestra una línea `Network: http://192.168.x.x:5173`. Esa es la dirección para los celulares.
4. Contraseña de administrador local: `profe-local` (está en `backend/.dev.vars`).

Notas: Windows puede pedir permiso de firewall para Node.js; acepte "Redes privadas". Algunas redes universitarias aíslan a los dispositivos entre sí; en ese caso use la versión publicada en internet.

## 3. Puesta en línea en 10 minutos

Se hace una sola vez. Necesita: una cuenta de GitHub (que ya tiene o crea gratis) y una cuenta gratuita de Cloudflare. Ninguna pide tarjeta.

### A. Cuenta de Cloudflare y servidor del juego

1. Vaya a https://dash.cloudflare.com/sign-up
2. Escriba su correo y una contraseña, pulse **Sign up** y confirme el correo que le llega.
3. Si le ofrece planes o dominios, ignórelo: no hace falta agregar ningún sitio ni dominio.
4. En una terminal, dentro de la carpeta del proyecto, ejecute:
   ```
   npx wrangler login
   ```
   Se abre el navegador: pulse **Allow**. La terminal dirá "Successfully logged in".
5. Publique el servidor:
   ```
   npm run deploy -w backend
   ```
   Si es la primera vez, Wrangler pregunta si quiere registrar un subdominio `workers.dev`: responda que sí y escriba un nombre corto (por ejemplo su usuario). Al terminar imprime una dirección parecida a:
   `https://juego-cartas-backend.SU-SUBDOMINIO.workers.dev`
   **Cópiela.**
6. Defina la contraseña real del profesor:
   ```
   cd backend
   npx wrangler secret put ADMIN_PASSWORD
   cd ..
   ```
   Escriba la contraseña cuando la pida y pulse Enter. (No se muestra mientras escribe.)
7. Compruebe: abra en el navegador la dirección del paso 5. Debe decir "Servidor del juego de cartas: OK".

### B. Página web en GitHub Pages

8. Vaya a https://github.com/new. En "Repository name" escriba `juego-cartas`, deje **Public** y pulse **Create repository**.
9. Suba el código. En la terminal, dentro de la carpeta del proyecto (cambie `SU-USUARIO`):
   ```
   git init
   git add .
   git commit -m "Juego de cartas"
   git branch -M main
   git remote add origin https://github.com/SU-USUARIO/juego-cartas.git
   git push -u origin main
   ```
10. En la página del repositorio: **Settings** → (menú izquierdo) **Secrets and variables** → **Actions** → pestaña **Variables** → **New repository variable**.
    * Name: `VITE_WS_URL`
    * Value: la dirección del paso 5 cambiando `https://` por `wss://` y agregando `/ws` al final. Ejemplo: `wss://juego-cartas-backend.SU-SUBDOMINIO.workers.dev/ws`
    * Pulse **Add variable**.
11. **Settings** → **Pages** → en "Build and deployment", "Source": elija **GitHub Actions**.
12. Pestaña **Actions** → a la izquierda **Publicar en GitHub Pages** → botón **Run workflow** → **Run workflow**. Espere el visto verde (1 o 2 minutos).
13. Su app queda en `https://SU-USUARIO.github.io/juego-cartas/` y el panel en `https://SU-USUARIO.github.io/juego-cartas/#/admin`.

### C. Actualizaciones futuras

* Cambios en la página: `git push` y GitHub la vuelve a publicar sola.
* Cambios en el servidor: `npm run deploy -w backend`.
* Cambiar la contraseña: repita el paso 6.

## 4. Costos y límites

Todo es gratuito y sin tarjeta. El plan gratuito de Cloudflare permite 100 000 solicitudes diarias; una clase completa usa unos pocos miles. Si algún día se superara un límite, la app dejaría de responder hasta las 7:00 p. m. hora de Colombia (00:00 UTC), sin ningún cobro.
