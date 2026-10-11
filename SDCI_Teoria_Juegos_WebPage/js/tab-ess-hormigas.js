/* 05 · Ejemplo 1 ESS: colonia de hormigas (cooperar o huir). */
(function () {
  "use strict";
  const { el, tex, clear } = App;

  const R = 2, Sx = -1, T = 5, P = 1;
  const J = [[R, Sx], [T, P]];          // filas/columnas: Cooperar, Huir
  const LAB = ["Cooperar", "Huir"];
  const DELAY = 1000;

  const SIMS = {
    1: { frames: [1, 2, 3, 4].map(k => "assets/img/ess1/" + k + ".png") },
    2: { frames: [1, 2, 3, 4, 5, 6, 7, 8].map(k => "assets/img/ess2/" + k + ".png") },
  };

  let img, dots, expl, btns, playing = false;

  function init() {
    img = App.$("#ess1-slide");
    dots = App.$("#ess1-dots");
    expl = App.$("#ess1-expl");
    btns = [App.$("#btn-ess-q1"), App.$("#btn-ess-q2")];

    buildText();
    buildMatrix();
    // Precarga de los fotogramas
    Object.values(SIMS).forEach(s => s.frames.forEach(src => { const i = new Image(); i.src = src; }));
    setDots(SIMS[1].frames.length, 0);

    btns[0].addEventListener("click", () => run(1));
    btns[1].addEventListener("click", () => run(2));
  }

  function buildText() {
    const host = App.$("#ess1-text");
    host.innerHTML =
      "<p>Imagine una colonia de hormigas en donde existen dos tipos distintos de comportamientos instintivos. En presencia de un ataque a la colonia, alguna proporción de las hormigas decide cooperar para enfrentar la amenaza, mientras las demás deciden huir (no cooperar) abandonando a las demás.</p>" +
      "<p>La matriz que se muestra indica el resultado de las interacciones entre ellas; los puntos indican un mayor o menor nivel de seguridad o posibilidades de supervivencia:</p>" +
      "<ul>" +
      "<li>Si una hormiga decide cooperar frente a otra que decide cooperar, ambas reciben un pago de \\(" + R + "\\), puesto que pueden defenderse juntas, pero pueden recibir daño de la araña.</li>" +
      "<li>Si una hormiga decide cooperar frente a otra que decide huir, aquella que huye recibe un pago de \\(" + T + "\\) (maximizando su supervivencia), mientras la que se queda sola recibe un pago de \\(" + Sx + "\\), indicando una posible muerte.</li>" +
      "<li>Si ambas hormigas deciden huir, ambas reciben un pago de \\(" + P + "\\) punto, ya que intentando huir ambas son vulnerables al ataque de la araña a pesar de no enfrentarla directamente.</li>" +
      "</ul>";
  }

  function buildMatrix() {
    const t = el("table", { class: "matrix" });
    const hr = el("tr");
    hr.appendChild(el("th"));
    LAB.forEach(l => hr.appendChild(el("th", { scope: "col" }, [el("span", { class: "head", text: "P2 " + l })])));
    t.appendChild(hr);
    J.forEach((row, i) => {
      const tr = el("tr");
      tr.appendChild(el("th", { scope: "row" }, [el("span", { class: "head", text: "P1 " + LAB[i] })]));
      row.forEach(v => {
        const c = el("div", { class: "cell" });
        c.appendChild(tex(String(v)));
        tr.appendChild(el("td", null, [c]));
      });
      t.appendChild(tr);
    });
    App.$("#ess1-matrix").appendChild(t);
  }

  function setDots(n, on) {
    clear(dots);
    for (let k = 0; k < n; k++) dots.appendChild(el("span", { class: k === on ? "on" : "" }));
  }

  // Reproduce la animación fotograma a fotograma y luego muestra la explicación
  function run(which) {
    if (playing) return;
    playing = true;
    clear(expl);
    btns.forEach(b => { b.disabled = true; });
    const r = img.getBoundingClientRect();
    if (r.top < 90 || r.bottom > window.innerHeight) {
      img.scrollIntoView({ behavior: "smooth", block: "center" });
    }
    const frames = SIMS[which].frames;
    let k = 0;
    const step = () => {
      if (k < frames.length) {
        img.src = frames[k];
        setDots(frames.length, k);
        k += 1;
        setTimeout(step, DELAY);
      } else {
        img.src = frames[0];
        setDots(frames.length, 0);
        btns.forEach(b => { b.disabled = false; });
        playing = false;
        explain(which);
      }
    };
    step();
  }

  /*
   * Explicaciones (corregidas). ε es la proporción de mutantes.
   * Pregunta 1: población desertora (1-ε) invadida por cooperadoras (ε)  ->  huir es ESS.
   * Pregunta 2: población cooperativa (1-ε) invadida por desertoras (ε)  ->  cooperar NO es ESS.
   */
  function explain(which) {
    const out = clear(expl);
    out.classList.remove("reveal"); void out.offsetWidth; out.classList.add("reveal");
    const card = el("div", { class: "card card-soft" });
    if (which === 1) {
      card.appendChild(el("div", { class: "expl-title", text: "Población desertora con una fracción \\(\\varepsilon\\) de mutantes cooperativas" }));
      card.appendChild(tex("\\begin{aligned}\\omega_{\\mathrm{C}} &= J_1^{11}\\,\\varepsilon + J_1^{12}(1-\\varepsilon) \\\\ &= " + R + "\\varepsilon - (1-\\varepsilon) = 3\\varepsilon - 1\\end{aligned}", true));
      card.appendChild(tex("\\begin{aligned}\\omega_{\\mathrm{NC}} &= J_1^{21}\\,\\varepsilon + J_1^{22}(1-\\varepsilon) \\\\ &= " + T + "\\varepsilon + 1 - \\varepsilon = 4\\varepsilon + 1\\end{aligned}", true));
      card.appendChild(tex("\\begin{aligned}\\omega_{\\mathrm{NC}} > \\omega_{\\mathrm{C}} &\\iff 4\\varepsilon + 1 > 3\\varepsilon - 1 \\\\ &\\iff \\varepsilon > -2\\end{aligned}", true));
      card.appendChild(el("p", { class: "concl", text: "Por definición \\(0 < \\varepsilon < 1\\), por lo tanto no cooperar (huir) es un ESS." }));
    } else {
      card.appendChild(el("div", { class: "expl-title", text: "Población cooperativa con una fracción \\(\\varepsilon\\) de mutantes desertoras" }));
      card.appendChild(tex("\\begin{aligned}\\omega_{\\mathrm{C}} &= J_1^{11}(1-\\varepsilon) + J_1^{12}\\,\\varepsilon \\\\ &= " + R + "(1-\\varepsilon) - \\varepsilon = 2 - 3\\varepsilon\\end{aligned}", true));
      card.appendChild(tex("\\begin{aligned}\\omega_{\\mathrm{NC}} &= J_1^{21}(1-\\varepsilon) + J_1^{22}\\,\\varepsilon \\\\ &= " + T + "(1-\\varepsilon) + \\varepsilon = 5 - 4\\varepsilon\\end{aligned}", true));
      card.appendChild(tex("\\begin{aligned}\\omega_{\\mathrm{NC}} > \\omega_{\\mathrm{C}} &\\iff 5 - 4\\varepsilon > 2 - 3\\varepsilon \\\\ &\\iff \\varepsilon < 3\\end{aligned}", true));
      card.appendChild(el("p", { class: "concl", text: "Como \\(0 < \\varepsilon < 1\\), siempre se cumple \\(\\omega_{\\mathrm{NC}} > \\omega_{\\mathrm{C}}\\). Por lo tanto cooperar NO es un ESS." }));
    }
    out.appendChild(card);
    App.renderMathIn(card);
  }

  App.registerTab(5, { init });
})();
