/* 01 · Ejemplo Motivador: juego de suma cero entre dos equipos de fútbol. */
(function () {
  "use strict";
  const { el, svg, tex, renderTex, clear } = App;

  // Matriz de pagos del equipo P1 (goles que encaja el equipo P2).
  const J = [
    [3, 4, 6],
    [2, 2, 4],
    [1, 3, 2],
  ];
  // Formaciones (defensa-medio-ataque). P1: filas, P2: columnas.
  const FORM_P1 = [[4, 3, 3], [4, 4, 2], [4, 5, 1]];
  const FORM_P2 = [[5, 3, 2], [4, 3, 3], [3, 4, 3]];

  const state = {
    left: [0, 0, 0],  // fila seleccionada (P1)
    top: [0, 0, 0],   // columna seleccionada (P2)
  };

  let cells = [];     // cells[i][j] -> element
  let leftBtns = [];
  let topBtns = [];
  let pitch, layerP1, layerP2, info;

  const MIN = "\\mathop{\\text{mín}}";
  const MAX = "\\mathop{\\text{máx}}";

  function init() {
    const grid = App.$("#fm-grid");
    info = App.$("#fm-info");
    pitch = App.$("#pitch");

    grid.appendChild(el("div", { class: "fm-team-top axis-label axis-p2", text: "Equipo P2" }));
    grid.appendChild(el("div", { class: "fm-team-side axis-label axis-p1", text: "Equipo P1" }));

    // Botones de estrategia del equipo P2 (columnas)
    for (let j = 0; j < 3; j++) {
      const b = el("button", {
        class: "fm-strat p2", type: "button", "aria-pressed": "false",
        "aria-label": "Equipo P2, estrategia " + (j + 1) + ": formación " + FORM_P2[j].join("-"),
        style: "grid-row: 2; grid-column: " + (j + 3),
      });
      b.appendChild(tex("\\theta^{2}_{" + (j + 1) + "} = " + FORM_P2[j].join("\\;")));
      b.addEventListener("click", () => highlightColumn(j));
      topBtns.push(b);
      grid.appendChild(b);
    }

    // Filas: botón de estrategia P1 + celdas
    for (let i = 0; i < 3; i++) {
      const b = el("button", {
        class: "fm-strat p1", type: "button", "aria-pressed": "false",
        "aria-label": "Equipo P1, estrategia " + (i + 1) + ": formación " + FORM_P1[i].join("-"),
        style: "grid-row: " + (i + 3) + "; grid-column: 2",
      });
      b.appendChild(tex("\\theta^{1}_{" + (i + 1) + "} = " + FORM_P1[i].join("\\;")));
      b.addEventListener("click", () => highlightRow(i));
      leftBtns.push(b);
      grid.appendChild(b);

      const row = [];
      for (let j = 0; j < 3; j++) {
        const c = el("div", {
          class: "fm-cell",
          text: String(J[i][j]),
          style: "grid-row: " + (i + 3) + "; grid-column: " + (j + 3),
          "aria-label": "Fila " + (i + 1) + ", columna " + (j + 1) + ": " + J[i][j],
        });
        row.push(c);
        grid.appendChild(c);
      }
      cells.push(row);
    }

    drawPitch();

    App.$("#btn-vmin").addEventListener("click", showVmin);
    App.$("#btn-vmax").addEventListener("click", showVmax);
    App.$("#btn-saddle").addEventListener("click", showSaddle);
  }

  /* ---------------------------------------------------------------- */
  /* Selección de filas y columnas (misma lógica que la app original) */
  /* ---------------------------------------------------------------- */
  function resetMatrix() {
    cells.forEach(r => r.forEach(c => c.classList.remove("is-hl")));
  }

  function resetOtherButtons(k, isLeft) {
    const btns = isLeft ? leftBtns : topBtns;
    const flags = isLeft ? state.left : state.top;
    btns.forEach((b, idx) => {
      if (idx !== k) { b.setAttribute("aria-pressed", "false"); flags[idx] = 0; }
    });
  }

  function selected(flags) {
    const idx = flags.findIndex(Boolean);
    return idx;
  }

  function highlightRow(i) {
    resetMatrix();
    resetOtherButtons(i, true);
    setInfo(null);
    if (state.left[i]) {
      state.left[i] = 0;
      leftBtns[i].setAttribute("aria-pressed", "false");
      const j = selected(state.top);
      if (j >= 0) cells.forEach(r => r[j].classList.add("is-hl"));
      else resetMatrix();
      drawFormation(1, null);
      return;
    }
    state.left[i] = 1;
    leftBtns[i].setAttribute("aria-pressed", "true");
    const j = selected(state.top);
    if (j >= 0) {
      cells[i][j].classList.add("is-hl");
      setInfo(i, j);
    } else {
      cells[i].forEach(c => c.classList.add("is-hl"));
    }
    drawFormation(1, i);
  }

  function highlightColumn(j) {
    resetMatrix();
    resetOtherButtons(j, false);
    setInfo(null);
    if (state.top[j]) {
      state.top[j] = 0;
      topBtns[j].setAttribute("aria-pressed", "false");
      const i = selected(state.left);
      if (i >= 0) cells[i].forEach(c => c.classList.add("is-hl"));
      else resetMatrix();
      drawFormation(2, null);
      return;
    }
    state.top[j] = 1;
    topBtns[j].setAttribute("aria-pressed", "true");
    const i = selected(state.left);
    if (i >= 0) {
      cells[i][j].classList.add("is-hl");
      setInfo(i, j);
    } else {
      cells.forEach(r => r[j].classList.add("is-hl"));
    }
    drawFormation(2, j);
  }

  function setInfo(i, j) {
    clear(info);
    if (i === null) return;
    const v = J[i][j];
    const keyword = v >= 0 ? "encajará" : "meterá";
    info.appendChild(el("span", {
      class: "reveal",
      text: "Si el equipo P1 utiliza su estrategia " + (i + 1) +
        " y el equipo P2 utiliza su estrategia " + (j + 1) +
        ", el equipo P2 " + keyword + " " + Math.abs(v) + " goles.",
    }));
  }

  /* ---------------------------------------------------------------- */
  /* Campo de juego (SVG)                                              */
  /* ---------------------------------------------------------------- */
  function drawPitch() {
    const W = 1050, H = 680, LINE = "#15C28C";
    const g = svg("g");
    // Franjas de césped
    for (let k = 0; k < 10; k++) {
      g.appendChild(svg("rect", { x: k * 105, y: 0, width: 105, height: H, fill: k % 2 ? "#F2FBF7" : "#E8F8F0" }));
    }
    const lines = svg("g", { fill: "none", stroke: LINE, "stroke-width": 4 });
    lines.appendChild(svg("rect", { x: 20, y: 20, width: W - 40, height: H - 40, rx: 6 }));
    lines.appendChild(svg("line", { x1: W / 2, y1: 20, x2: W / 2, y2: H - 20 }));
    lines.appendChild(svg("circle", { cx: W / 2, cy: H / 2, r: 91 }));
    // Áreas
    lines.appendChild(svg("rect", { x: 20, y: H / 2 - 201, width: 165, height: 402 }));
    lines.appendChild(svg("rect", { x: W - 185, y: H / 2 - 201, width: 165, height: 402 }));
    lines.appendChild(svg("rect", { x: 20, y: H / 2 - 92, width: 55, height: 184 }));
    lines.appendChild(svg("rect", { x: W - 75, y: H / 2 - 92, width: 55, height: 184 }));
    lines.appendChild(svg("path", { d: "M185 " + (H / 2 - 73) + " A91 91 0 0 1 185 " + (H / 2 + 73) }));
    lines.appendChild(svg("path", { d: "M" + (W - 185) + " " + (H / 2 - 73) + " A91 91 0 0 0 " + (W - 185) + " " + (H / 2 + 73) }));
    // Porterías
    lines.appendChild(svg("rect", { x: 6, y: H / 2 - 37, width: 14, height: 74 }));
    lines.appendChild(svg("rect", { x: W - 20, y: H / 2 - 37, width: 14, height: 74 }));
    g.appendChild(lines);
    g.appendChild(svg("circle", { cx: W / 2, cy: H / 2, r: 6, fill: LINE }));
    pitch.appendChild(g);

    layerP1 = svg("g");
    layerP2 = svg("g");
    pitch.appendChild(layerP1);
    pitch.appendChild(layerP2);

    const hint = svg("text", {
      id: "pitch-hint", x: W / 2, y: H - 40, "text-anchor": "middle",
      "font-family": "Figtree, sans-serif", "font-size": 26, "font-weight": 600, fill: "#4B4866",
    });
    hint.textContent = "Seleccione una formación para cada equipo";
    pitch.appendChild(hint);
  }

  function drawFormation(team, idx) {
    const W = 1050, H = 680;
    const layer = team === 1 ? layerP1 : layerP2;
    clear(layer);
    if (idx !== null) {
      const form = team === 1 ? FORM_P1[idx] : FORM_P2[idx];
      const color = team === 1 ? "#5C3DEE" : "#20ACA4";
      const xs = [190, 330, 465];             // defensa, medio, ataque (mitad izquierda)
      const pts = [{ x: 62, y: H / 2, gk: true }];
      form.forEach((n, line) => {
        for (let k = 0; k < n; k++) pts.push({ x: xs[line], y: 40 + (H - 80) * (k + 1) / (n + 1) });
      });
      pts.forEach((p, n) => {
        const x = team === 1 ? p.x : W - p.x;
        const c = svg("circle", {
          cx: x, cy: p.y, r: p.gk ? 21 : 19,
          fill: p.gk ? "#FFFFFF" : color,
          stroke: p.gk ? color : "#FFFFFF",
          "stroke-width": p.gk ? 7 : 4,
          class: "reveal",
          style: "animation-delay:" + (n * 18) + "ms",
        });
        layer.appendChild(c);
      });
    }
    const anySel = state.left.some(Boolean) || state.top.some(Boolean);
    const hint = App.$("#pitch-hint");
    if (hint) hint.style.display = anySel ? "none" : "";
  }

  /* ---------------------------------------------------------------- */
  /* v⁻, v⁺ y saddle point                                             */
  /* ---------------------------------------------------------------- */
  const rowMin = J.map(r => Math.min(...r));
  const colMax = J[0].map((_, j) => Math.max(...J.map(r => r[j])));
  const vMinus = Math.max(...rowMin);
  const vPlus = Math.min(...colMax);

  function setMark(i, j, cls) {
    const c = cells[i][j];
    c.classList.remove("mark-min", "mark-max");
    c.classList.add(cls);
  }

  function showVmin() {
    const out = clear(App.$("#out-vmin"));
    J.forEach((r, i) => {
      const terms = r.map((_, j) => "J_1^{" + (i + 1) + (j + 1) + "}").join(",");
      out.appendChild(tex(
        "\\begin{aligned}" + MIN + "\\limits_{j=1,2,3} J_1^{" + (i + 1) + "j} &= " + MIN + "\\{" + terms + "\\} \\\\ &= " +
        MIN + "\\{" + r.join(",") + "\\} = " + rowMin[i] + "\\end{aligned}", true));
      setMark(i, r.indexOf(rowMin[i]), "mark-min");
    });
    const parts = J.map(r => MIN + "\\{" + r.join(",") + "\\}");
    out.appendChild(tex("\\begin{aligned} v^- &= " + MAX + "\\{" + parts[0] + ",\\, " + parts[1] + ", \\\\ &\\qquad " + parts[2] +
      "\\} \\\\ &= " + MAX + "\\{" + rowMin.join(",") + "\\} = \\boxed{" + vMinus + "}\\end{aligned}", true));
    out.classList.add("reveal");
  }

  function showVmax() {
    const out = clear(App.$("#out-vmax"));
    colMax.forEach((m, j) => {
      const col = J.map(r => r[j]);
      const terms = col.map((_, i) => "J_1^{" + (i + 1) + (j + 1) + "}").join(",");
      out.appendChild(tex(
        "\\begin{aligned}" + MAX + "\\limits_{i=1,2,3} J_1^{i" + (j + 1) + "} &= " + MAX + "\\{" + terms + "\\} \\\\ &= " +
        MAX + "\\{" + col.join(",") + "\\} = " + m + "\\end{aligned}", true));
      setMark(col.indexOf(m), j, "mark-max");
    });
    const parts = colMax.map((_, j) => MAX + "\\{" + J.map(r => r[j]).join(",") + "\\}");
    out.appendChild(tex("\\begin{aligned} v^+ &= " + MIN + "\\{" + parts[0] + ",\\, " + parts[1] + ", \\\\ &\\qquad " + parts[2] +
      "\\} \\\\ &= " + MIN + "\\{" + colMax.join(",") + "\\} = \\boxed{" + vPlus + "}\\end{aligned}", true));
    out.classList.add("reveal");
  }

  function showSaddle() {
    const out = clear(App.$("#out-saddle"));
    const p = el("p", { class: "prose" });
    if (vMinus === vPlus) {
      const iStar = rowMin.indexOf(vMinus) + 1;
      const jStar = colMax.indexOf(vPlus) + 1;
      p.appendChild(document.createTextNode("¿Es "));
      p.appendChild(tex("v^- = v^+"));
      p.appendChild(document.createTextNode("? Sí, entonces la fila "));
      p.appendChild(tex("i^* = " + iStar));
      p.appendChild(document.createTextNode(" y columna "));
      p.appendChild(tex("j^* = " + jStar));
      p.appendChild(document.createTextNode(" corresponden a un saddle point en estrategias puras."));
    } else {
      p.appendChild(document.createTextNode("¿Es "));
      p.appendChild(tex("v^- = v^+"));
      p.appendChild(document.createTextNode("? No, el juego no tiene un saddle point en estrategias puras."));
    }
    out.appendChild(p);
    out.classList.add("reveal");
  }

  App.registerTab(1, { init });
})();
