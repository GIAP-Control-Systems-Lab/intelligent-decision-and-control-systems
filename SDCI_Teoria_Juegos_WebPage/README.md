# Herramienta de Soporte Interactiva (Semana 6)

Versión web de la herramienta de escritorio `Herramienta de Soporte Interactiva.exe`. Funciona por completo en el navegador (computador, iPhone, iPad y Android) y se puede publicar gratis en GitHub Pages. No necesita servidor, base de datos ni instalación.

## Contenido

| Pestaña | Qué hace |
|---|---|
| 01 · Ejemplo Motivador | Matriz 3×3 entre dos equipos de fútbol. Al elegir formaciones se resaltan filas, columnas o la celda y se dibujan en el campo. Botones para calcular $v^-$, $v^+$ y el saddle point. |
| 02 · Ejemplo Estrategias Mixtas | Piedra, papel o tijeras. Se arrastra un punto dentro del triángulo para fijar $\pi_1$; el jugador 2 responde con su best response y se calcula el valor esperado. |
| 03 · Ejemplo Juegos de Suma No Cero | Juego de la gallina con los dos autos. Clic o toque en la carretera para frenar, matrices de pago resaltadas y comprobación del equilibrio de Nash. |
| 04 · Ejemplo Juegos Simétricos | Dividir o robar contra dos oponentes (uno al azar que puede mentir y otro que juega ojo por ojo). |
| 05 · Ejemplo 1 ESS | Colonia de hormigas: animaciones de las dos preguntas y la explicación matemática del ESS. |
| 06 · Ejemplo 2 ESS | Halcón-paloma con sliders para $V$ y $C$ y gráfico de la estrategia mixta $\pi^*$. |

Toda la notación matemática se escribe en LaTeX y se dibuja con KaTeX (incluido en la carpeta `vendor/`, no depende de internet).

## Cambios respecto a la versión de escritorio

- Las fórmulas que antes eran capturas de pantalla ahora se generan en LaTeX a partir de las propias matrices.
- Se corrigieron tres errores aritméticos de las capturas originales:
  - Gallina, (P1 frena, P2 acelera): decía $-1 \le 2$; lo correcto es $-1 \le 0$.
  - ESS, población cooperativa: decía $\omega_C = 2-2\varepsilon$ y $\omega_{NC} = 5-2\varepsilon$; lo correcto es $2-3\varepsilon$ y $5-4\varepsilon$.
  - ESS, población desertora: decía $3\varepsilon-1 > 4\varepsilon+1 \Rightarrow \varepsilon<2$; lo correcto es $4\varepsilon+1 > 3\varepsilon-1 \iff \varepsilon > -2$.
- Las dos explicaciones del Ejemplo 1 ESS quedaron asociadas a la pregunta que realmente responden.
- En el juego de la gallina ya se puede frenar desde la primera partida.
- La 2.ª condición del equilibrio de Nash se escribe con $\forall j$ (antes decía $\forall i$).

## Estructura de archivos

```
sitio-web/
├── index.html                 Página principal (las 6 pestañas)
├── .nojekyll                  Indica a GitHub Pages que publique los archivos tal cual
├── css/styles.css             Diseño (colores, tipografía, adaptación a celulares)
├── js/
│   ├── core.js                Utilidades compartidas (KaTeX, creación de elementos)
│   ├── app.js                 Navegación entre pestañas
│   ├── tab-motivador.js       Pestaña 01
│   ├── tab-mixtas.js          Pestaña 02
│   ├── tab-gallina.js         Pestaña 03
│   ├── tab-dividir-robar.js   Pestaña 04
│   ├── tab-ess-hormigas.js    Pestaña 05
│   └── tab-ess-halcon-paloma.js  Pestaña 06
├── assets/img/                Imágenes (autos, animales, personas, fotogramas de las hormigas)
└── vendor/katex/              KaTeX 0.16 (licencia MIT)
```

## Deployment Guide (publicar en GitHub Pages)

No se necesita saber programar. Solo un navegador (Chrome, Edge, Safari o Firefox) en un computador.

### 1. Crear una cuenta en GitHub
Entre a <https://github.com> y haga clic en **Sign up**. Si ya tiene cuenta, inicie sesión.

### 2. Crear un repositorio nuevo
1. Arriba a la derecha, haga clic en el botón **+** y luego en **New repository**.
2. En **Repository name** escriba un nombre corto, por ejemplo `herramienta-soporte`.
3. Marque **Public**. (GitHub Pages gratuito requiere que el repositorio sea público.)
4. Haga clic en **Create repository**.

### 3. Subir los archivos
1. En la página del repositorio recién creado, haga clic en el enlace **uploading an existing file**.
2. Abra la carpeta `sitio-web` en su computador, seleccione **todo su contenido** (no la carpeta en sí, sino lo que hay dentro: `index.html`, `css`, `js`, `assets`, `vendor`…) y arrástrelo a la ventana del navegador.
   - Importante: `index.html` debe quedar en la raíz del repositorio, no dentro de otra carpeta.
   - Si su sistema oculta el archivo `.nojekyll`, no pasa nada; el sitio funciona igual sin él.
3. Espere a que termine de cargar la lista de archivos y haga clic en **Commit changes**.

### 4. Activar GitHub Pages
1. En el repositorio, haga clic en **Settings** (pestaña con el ícono de engranaje).
2. En el menú de la izquierda, haga clic en **Pages**.
3. En **Build and deployment → Source**, elija **Deploy from a branch**.
4. En **Branch**, elija **main** y la carpeta **/ (root)**. Haga clic en **Save**.

### 5. Abrir el sitio
Después de uno o dos minutos, recargue la página de **Settings → Pages**. Arriba aparecerá el enlace público, con esta forma:

```
https://SU-USUARIO.github.io/herramienta-soporte/
```

Ese enlace se puede compartir con los estudiantes y abrir desde cualquier computador, tableta o celular.

Para ir directamente a una pestaña, agregue `#ejemplo-N` al final del enlace (por ejemplo `.../#ejemplo-3` abre el juego de la gallina).

### Actualizar el sitio más adelante
Repita el paso 3 con los archivos modificados: GitHub reemplaza los archivos con el mismo nombre. El sitio se actualiza solo en uno o dos minutos.

### Probarlo sin internet
También puede abrir `index.html` con doble clic: todo funciona localmente. Sin conexión solo cambia la tipografía (se usa la del sistema).
