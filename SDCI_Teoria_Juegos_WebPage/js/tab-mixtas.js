/* 02 · Ejemplo Estrategias Mixtas: piedra, papel o tijeras. */
(function () {
  "use strict";
  const { el, svg, tex, clear, f2 } = App;

  // Matriz de pagos del jugador 1 (filas: J1, columnas: J2). Juego de suma cero: J2 = -J1.
  const A = [
    [0, -1, 1],
    [1, 0, -1],
    [-1, 1, 0],
  ];
  const NAMES = ["Piedra", "Papel", "Tijeras"];
  const ICONS = ["assets/img/rock.png", "assets/img/paper.png", "assets/img/scissors.png"];

  // Geometría del triángulo (mismas coordenadas que la app original)
  const V = [{ x: 160, y: 30 }, { x: 40, y: 270 }, { x: 280, y: 270 }];
  const CENTER = { x: (V[0].x + V[1].x + V[2].x) / 3, y: (V[0].y + V[1].y + V[2].y) / 3 };
  const RADIUS = 7;

  let prob = [1, 0, 0];
  let pos = { x: V[0].x, y: V[0].y };
  let svgEl, handle, halo, readout;
  let dragging = false;

  function init() {
    buildMatrix();
    buildSimplex();
    App.$("#btn-rps-play").addEventListener("click", play);
    App.$("#btn-rps-nash").addEventListener("click", showNash);
  }

  function buildMatrix() {
    const t = el("table", { class: "matrix", "aria-label": "Matriz de pagos del jugador 1" });
    const head = el("tr");
    head.appendChild(el("th", { colspan: 2 }));
    head.appendChild(el("th", { colspan: 3, class: "axis-label axis-p2", text: "Jugador 2" }));
    t.appendChild(head);
    const icons = el("tr");
    icons.appendChild(el("th"));
    icons.appendChild(el("th"));
    NAMES.forEach((n, j) => icons.appendChild(el("th", { class: "icon-head", scope: "col" }, [el("img", { src: ICONS[j], alt: n, title: n })])));
    t.appendChild(icons);
    A.forEach((row, i) => {
      const tr = el("tr");
      if (i === 0) {
        const th = el("th", { rowspan: 3, class: "axis-label axis-p1", style: "writing-mode: vertical-rl; transform: rotate(180deg); padding: 0 4px; white-space: nowrap;", text: "Jugador 1" });
        tr.appendChild(th);
      }
      tr.appendChild(el("th", { class: "icon-head", scope: "row" }, [el("img", { src: ICONS[i], alt: NAMES[i], title: NAMES[i] })]));
      row.forEach(v => {
        const td = el("td");
        const c = el("div", { class: "cell" });
        c.appendChild(tex(String(v)));
        td.appendChild(c);
        tr.appendChild(td);
      });
      t.appendChild(tr);
    });
    App.$("#rps-matrix").appendChild(t);
  }

  function buildSimplex() {
    svgEl = App.$("#simplex");
    readout = App.$("#pi-readout");

    const defs = svg("defs");
    const grad = svg("linearGradient", { id: "simplexFill", x1: "0", y1: "0", x2: "1", y2: "1" });
    grad.appendChild(svg("stop", { offset: "0%", "stop-color": "#EFEBFF" }));
    grad.appendChild(svg("stop", { offset: "100%", "stop-color": "#E3F6F4" }));
    defs.appendChild(grad);
    svgEl.appendChild(defs);

    const pts = V.map(p => p.x + "," + p.y).join(" ");
    const tri = svg("polygon", { points: pts, fill: "url(#simplexFill)", stroke: "#5C3DEE", "stroke-width": 2, "stroke-linejoin": "round" });
    svgEl.appendChild(tri);

    // Medianas tenues, como guía visual
    const guides = svg("g", { stroke: "#5C3DEE", "stroke-opacity": .18, "stroke-width": 1, "stroke-dasharray": "3 4" });
    V.forEach((p, k) => {
      const a = V[(k + 1) % 3], b = V[(k + 2) % 3];
      guides.appendChild(svg("line", { x1: p.x, y1: p.y, x2: (a.x + b.x) / 2, y2: (a.y + b.y) / 2 }));
    });
    svgEl.appendChild(guides);
    svgEl.appendChild(svg("circle", { cx: CENTER.x, cy: CENTER.y, r: 2.5, fill: "#5C3DEE", "fill-opacity": .35 }));

    // Etiquetas de los vértices
    const offs = [{ dx: 0, dy: -12, a: "middle" }, { dx: -6, dy: 20, a: "middle" }, { dx: 6, dy: 20, a: "middle" }];
    V.forEach((p, k) => {
      const t = svg("text", {
        x: p.x + offs[k].dx, y: p.y + offs[k].dy, "text-anchor": offs[k].a,
        "font-family": "Figtree, sans-serif", "font-size": 13, "font-weight": 700, fill: "#4A2DD6",
      });
      t.textContent = NAMES[k];
      svgEl.appendChild(t);
    });

    halo = svg("circle", { r: 16, fill: "#5C3DEE", "fill-opacity": .14, class: "handle" });
    handle = svg("circle", { r: RADIUS, fill: "#5C3DEE", stroke: "#fff", "stroke-width": 2.5, class: "handle" });
    svgEl.appendChild(halo);
    svgEl.appendChild(handle);

    // Interacción: arrastrar el punto o tocar dentro del triángulo
    svgEl.addEventListener("pointerdown", onDown);
    svgEl.addEventListener("pointermove", onMove);
    svgEl.addEventListener("pointerup", onUp);
    svgEl.addEventListener("pointercancel", onUp);

    // Teclado
    svgEl.setAttribute("tabindex", "0");
    svgEl.addEventListener("keydown", e => {
      const step = e.shiftKey ? 12 : 4;
      const d = { ArrowLeft: [-step, 0], ArrowRight: [step, 0], ArrowUp: [0, -step], ArrowDown: [0, step] }[e.key];
      if (!d) return;
      e.preventDefault();
      moveTo(pos.x + d[0], pos.y + d[1]);
    });

    place(pos.x, pos.y);
  }

  function toSvg(e) {
    const pt = svgEl.createSVGPoint();
    pt.x = e.clientX; pt.y = e.clientY;
    const m = svgEl.getScreenCTM();
    return m ? pt.matrixTransform(m.inverse()) : { x: pos.x, y: pos.y };
  }

  function onDown(e) {
    const p = toSvg(e);
    const nearHandle = Math.hypot(p.x - pos.x, p.y - pos.y) <= 22;
    if (!nearHandle && !inside(p.x, p.y)) return;
    dragging = true;
    svgEl.classList.add("dragging");
    try { svgEl.setPointerCapture(e.pointerId); } catch (err) { /* ignore */ }
    if (!nearHandle) moveTo(p.x, p.y);
    e.preventDefault();
  }

  function onMove(e) {
    if (!dragging) return;
    const p = toSvg(e);
    moveTo(p.x, p.y);
  }

  function onUp(e) {
    if (!dragging) return;
    dragging = false;
    svgEl.classList.remove("dragging");
    // Ajuste a vértices y al baricentro (como en la app original)
    const snapDist = (e.pointerType === "touch") ? 10 : 6;
    const snapPts = V.concat([CENTER]);
    let best = null, bestD = Infinity;
    snapPts.forEach(s => {
      const d = Math.hypot(s.x - pos.x, s.y - pos.y);
      if (d < bestD) { bestD = d; best = s; }
    });
    if (bestD <= snapDist) place(best.x, best.y);
  }

  function moveTo(x, y) {
    const c = inside(x, y) ? { x, y } : closestOnTriangle(x, y);
    place(c.x, c.y);
  }

  function place(x, y) {
    pos = { x, y };
    handle.setAttribute("cx", x); handle.setAttribute("cy", y);
    halo.setAttribute("cx", x); halo.setAttribute("cy", y);
    updateProbabilities(x, y);
  }

  function sign(p1, p2, p3) {
    return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
  }

  function inside(x, y) {
    const p = { x, y };
    const b1 = sign(p, V[0], V[1]) < 0;
    const b2 = sign(p, V[1], V[2]) < 0;
    const b3 = sign(p, V[2], V[0]) < 0;
    return b1 === b2 && b2 === b3;
  }

  function closestOnTriangle(x, y) {
    let best = null, bestD = Infinity;
    for (let k = 0; k < 3; k++) {
      const a = V[k], b = V[(k + 1) % 3];
      const abx = b.x - a.x, aby = b.y - a.y;
      let t = ((x - a.x) * abx + (y - a.y) * aby) / (abx * abx + aby * aby);
      t = Math.max(0, Math.min(1, t));
      const q = { x: a.x + t * abx, y: a.y + t * aby };
      const d = Math.hypot(q.x - x, q.y - y);
      if (d < bestD) { bestD = d; best = q; }
    }
    return best;
  }

  // Coordenadas baricéntricas por áreas (idéntico a la app original)
  function updateProbabilities(x, y) {
    const [a, b, c] = V;
    const area = (p, q, r) => Math.abs((p.x * (q.y - r.y) + q.x * (r.y - p.y) + r.x * (p.y - q.y)) / 2);
    const P = { x, y };
    const abc = area(a, b, c);
    let pa = area(P, b, c) / abc;
    let pb = area(a, P, c) / abc;
    let pc = area(a, b, P) / abc;
    const s = pa + pb + pc;           // corrige el error numérico en los bordes
    pa /= s; pb /= s; pc /= s;
    prob = [pa, pb, pc];
    App.renderTex(readout, "\\pi_1 = [" + f2(pa) + ",\\ " + f2(pb) + ",\\ " + f2(pc) + "]");
  }

  /* ---------------------------------------------------------------- */
  /* Mejor respuesta del jugador 2 y valor esperado                    */
  /* ---------------------------------------------------------------- */
  function bestResponse(pi1) {
    // Pago del jugador 2 al jugar piedra, papel o tijeras frente a pi1
    const sigmaR = pi1[1] - pi1[2];
    const sigmaP = -pi1[0] + pi1[2];
    const sigmaT = pi1[0] - pi1[1];
    const vect = [-sigmaR, -sigmaP, -sigmaT];
    const EPS = 1e-9;
    if (Math.abs(sigmaR) < EPS && Math.abs(sigmaP) < EPS && Math.abs(sigmaT) < EPS) {
      return [1 / 3, 1 / 3, 1 / 3];
    }
    const maxV = Math.max(...vect);
    const idx = vect.findIndex(v => v >= maxV - EPS);
    const pi2 = [0, 0, 0];
    pi2[idx] = 1;
    return pi2;
  }

  function expected(pi1, pi2) {
    let w = 0;
    for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) w += pi1[i] * A[i][j] * pi2[j];
    return w;
  }

  function vec(p) { return "[" + p.map(f2).join(",\\ ") + "]"; }

  function play() {
    const pi1 = prob.slice();
    const pi2 = bestResponse(pi1);
    const w1 = expected(pi1, pi2);
    const w2 = -w1;
    const out = clear(App.$("#rps-outcome"));
    out.classList.remove("reveal"); void out.offsetWidth; out.classList.add("reveal");

    const p = el("p");
    p.appendChild(document.createTextNode("Con las estrategias "));
    p.appendChild(tex("\\pi_1 = " + vec(pi1)));
    p.appendChild(document.createTextNode(" y "));
    p.appendChild(tex("\\pi_2 = " + vec(pi2)));
    p.appendChild(document.createTextNode(", el valor esperado del jugador 1 es de "));
    p.appendChild(tex("\\omega_1(\\pi_1,\\pi_2) = " + f2(w1)));
    p.appendChild(document.createTextNode(" y del jugador 2 es de "));
    p.appendChild(tex("\\omega_2(\\pi_1,\\pi_2) = " + f2(w2)));
    p.appendChild(document.createTextNode("."));
    out.appendChild(p);

    out.appendChild(el("p", { text: "Compruébelo mediante las operaciones" }));
    out.appendChild(tex("\\omega_1(\\pi_1,\\pi_2) = \\pi_1\\, J_1\\, \\pi_2^{\\top}", true));
    out.appendChild(el("p", { text: "y" }));
    out.appendChild(tex("\\omega_2(\\pi_1,\\pi_2) = -\\,\\omega_1(\\pi_1,\\pi_2)", true));
    out.appendChild(el("p", { class: "hint", text: "(al tratarse de un juego de suma cero)." }));
  }

  function showNash() {
    const out = clear(App.$("#rps-nash"));
    out.classList.add("reveal");
    out.appendChild(el("p", { text: "Como habrá notado, no existe un equilibrio de Nash en estrategias puras. Si un jugador empleara siempre la misma estrategia, el otro jugador tendría un incentivo para modificar su estrategia para ganar." }));
    const p = el("p");
    p.appendChild(document.createTextNode("Sin embargo, existe un equilibrio de Nash en estrategias mixtas cuando"));
    out.appendChild(p);
    out.appendChild(tex("\\pi_1 = \\left[\\tfrac{1}{3},\\, \\tfrac{1}{3},\\, \\tfrac{1}{3}\\right], \\qquad \\pi_2 = \\left[\\tfrac{1}{3},\\, \\tfrac{1}{3},\\, \\tfrac{1}{3}\\right].", true));
    out.appendChild(el("p", { text: "Note cómo estos valores hacen que los jugadores sean indiferentes ante sus estrategias. Si, por el contrario, alguno de los jugadores decidiera jugar con más frecuencia una estrategia, el otro se aprovecharía ajustando su estrategia para obtener un mayor valor esperado." }));
  }

  App.registerTab(2, { init });
})();
