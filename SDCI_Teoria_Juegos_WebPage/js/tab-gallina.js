/* 03 · Ejemplo Juegos de Suma No Cero: juego de la gallina. */
(function () {
  "use strict";
  const { el, svg, tex, clear } = App;

  // Estrategias: 0 = frena, 1 = acelera
  const STRAT = ["frena", "acelera"];
  const PAY1 = [[3, 0], [4, -1]];  // pagos del jugador 1
  const PAY2 = [[3, 4], [0, -1]];  // pagos del jugador 2
  const W = 200, H = 500, CAR = 50, TICK = 50;

  const S = {
    swerve1: false,          // el jugador 1 frena
    swerve2: false,          // el jugador 2 frena
    pair: [1, 1],            // [estrategia P1, estrategia P2]
    car1: { x: W / 2, y: H },
    car2: { x: W / 2, y: 0 },
    running: false,
    timer: null,
    started: false,
  };

  let road, car1El, car2El, crashEl, labels;

  function init() {
    road = App.$("#road-svg");
    buildRoad();
    labels = {
      m1: buildMatrix(App.$("#chicken-m1"), PAY1),
      m2: buildMatrix(App.$("#chicken-m2"), PAY2),
    };

    const roadBox = App.$("#road");
    roadBox.addEventListener("pointerdown", e => { e.preventDefault(); brake(); });
    roadBox.addEventListener("keydown", e => {
      if (e.key === "Enter" || e.key === " ") { e.preventDefault(); brake(); }
    });

    App.$("#btn-replay").addEventListener("click", () => replay(true));
    App.$("#btn-chicken-ne").addEventListener("click", showNE);

    setInstructions();
    lightUp();
  }

  // La primera partida empieza al mostrar la pestaña (como en la app original).
  function onShow() {
    if (!S.started) {
      S.started = true;
      setTimeout(() => replay(false), 700);
    }
  }

  /* ---------------------------------------------------------------- */
  /* Dibujo                                                            */
  /* ---------------------------------------------------------------- */
  function buildRoad() {
    clear(road);
    const defs = svg("defs");
    const g = svg("linearGradient", { id: "asphalt", x1: 0, y1: 0, x2: 1, y2: 0 });
    g.appendChild(svg("stop", { offset: "0%", "stop-color": "#2A2747" }));
    g.appendChild(svg("stop", { offset: "50%", "stop-color": "#34315A" }));
    g.appendChild(svg("stop", { offset: "100%", "stop-color": "#2A2747" }));
    defs.appendChild(g);
    road.appendChild(defs);
    road.appendChild(svg("rect", { x: 0, y: 0, width: W, height: H, fill: "url(#asphalt)" }));
    // Bordes de la vía
    road.appendChild(svg("rect", { x: 8, y: 0, width: 4, height: H, fill: "#15C28C", opacity: .9 }));
    road.appendChild(svg("rect", { x: W - 12, y: 0, width: 4, height: H, fill: "#15C28C", opacity: .9 }));
    // Línea central discontinua (mismas posiciones que la original)
    const t = 10;
    for (let i = -200; i < 300; i += 100) {
      road.appendChild(svg("rect", { x: W / 2 - t / 2, y: i + H / 2 - 2 * t, width: t, height: 4 * t, rx: 2, fill: "#FFFFFF", opacity: .92 }));
    }
    car1El = svg("image", { href: "assets/img/car1.png", width: CAR, height: CAR });
    car2El = svg("image", { href: "assets/img/car2.png", width: CAR, height: CAR });
    crashEl = svg("image", { href: "assets/img/crash.png", width: CAR, height: CAR, x: W / 2 - CAR / 2, y: H / 2 - CAR / 2, visibility: "hidden" });
    road.appendChild(car1El);
    road.appendChild(car2El);
    road.appendChild(crashEl);
    drawCars();
  }

  function drawCars() {
    car1El.setAttribute("x", S.car1.x - CAR / 2);
    car1El.setAttribute("y", S.car1.y - CAR / 2);
    car2El.setAttribute("x", S.car2.x - CAR / 2);
    car2El.setAttribute("y", S.car2.y - CAR / 2);
  }

  function buildMatrix(host, pay) {
    const t = el("table", { class: "matrix" });
    const hr = el("tr");
    hr.appendChild(el("th"));
    const colLabs = STRAT.map(s => el("span", { class: "head", text: "P2 " + s }));
    colLabs.forEach(l => hr.appendChild(el("th", { scope: "col" }, [l])));
    t.appendChild(hr);
    const rowLabs = [];
    pay.forEach((row, i) => {
      const tr = el("tr");
      const l = el("span", { class: "head", text: "P1 " + STRAT[i] });
      rowLabs.push(l);
      tr.appendChild(el("th", { scope: "row" }, [l]));
      row.forEach(v => {
        const c = el("div", { class: "cell" });
        c.appendChild(tex(String(v)));
        tr.appendChild(el("td", null, [c]));
      });
      t.appendChild(tr);
    });
    host.appendChild(t);
    return { rows: rowLabs, cols: colLabs };
  }

  function lightUp() {
    [labels.m1, labels.m2].forEach(m => {
      m.rows.forEach((l, i) => l.classList.toggle("is-on", S.pair[0] === i));
      m.cols.forEach((l, j) => l.classList.toggle("is-on", S.pair[1] === j));
    });
  }

  function setInstructions() {
    App.$("#chicken-instr").textContent =
      "En términos de estrategias puras, usted (Jugador 1) ha decidido acelerar, el jugador 2 ha decidido " +
      STRAT[S.pair[1]] + "r. Si desea cambiar su estrategia a frenar, haga clic (o toque) sobre la carretera durante el juego.";
  }

  /* ---------------------------------------------------------------- */
  /* Juego                                                             */
  /* ---------------------------------------------------------------- */
  function replay(randomOpponent) {
    clearTimeout(S.timer);
    S.swerve1 = false;
    S.swerve2 = false;
    S.car1 = { x: W / 2, y: H };
    S.car2 = { x: W / 2, y: 0 };
    // Primera partida: el jugador 2 acelera. Después elige al azar.
    S.pair = [1, randomOpponent ? (Math.random() < 0.5 ? 0 : 1) : 1];
    if (S.pair[1] === 0) S.swerve2 = true;
    crashEl.setAttribute("visibility", "hidden");
    drawCars();
    setInstructions();
    lightUp();
    clear(App.$("#chicken-ne"));
    clear(App.$("#chicken-pay"));
    App.$("#road-status").textContent = "En marcha: haga clic o toque la carretera para frenar.";
    App.$("#btn-replay").disabled = true;
    S.running = true;
    tick();
  }

  // El jugador 1 frena (solo antes de cruzarse con el otro auto).
  function brake() {
    if (!S.running || S.swerve1) return;
    if (S.car1.y > 215) {
      S.swerve1 = true;
      S.pair = [0, S.swerve2 ? 0 : 1];
      lightUp();
      App.$("#road-status").textContent = "Usted decidió frenar.";
    }
  }

  function move(car, dx, dy) { car.x += dx; car.y += dy; }

  // Misma cinemática que la app original (pasos de 10 unidades cada 50 ms)
  function tick() {
    const c1 = S.car1, c2 = S.car2;
    let stop1, stop2;
    if (S.swerve1 && !S.swerve2) {
      move(c2, 0, 10);
      stop1 = 0; stop2 = 500;
      if (c1.y > c2.y) move(c1, -5, -10);
    } else if (!S.swerve1 && S.swerve2) {
      move(c1, 0, -10);
      stop1 = 0; stop2 = 500;
      if (c2.y < 200) move(c2, 0, 10);
      else if (c2.y >= 200 && c2.y < 260) move(c2, 5, 10);
    } else if (S.swerve1 && S.swerve2) {
      stop1 = 0; stop2 = 260;
      if (c2.y < 200) move(c2, 0, 10);
      else if (c2.y >= 200 && c2.y <= 260) move(c2, 5, 10);
      if (c1.y > 230 && c2.y <= 260) move(c1, -5, -10);
    } else {
      move(c1, 0, -10);
      move(c2, 0, 10);
      stop1 = 230; stop2 = 230;
    }
    drawCars();

    if (c1.y <= stop1 || c2.y >= stop2) {
      finish();
      return;
    }
    S.timer = setTimeout(tick, TICK);
  }

  function finish() {
    S.running = false;
    if (!S.swerve1 && !S.swerve2) crashEl.setAttribute("visibility", "visible");
    const [i, j] = S.pair;
    const out = clear(App.$("#chicken-pay"));
    out.classList.remove("reveal"); void out.offsetWidth; out.classList.add("reveal");
    out.appendChild(document.createTextNode("El pago de P1 es "));
    out.appendChild(tex("\\omega_1(" + (i + 1) + "," + (j + 1) + ") = " + PAY1[i][j]));
    out.appendChild(document.createTextNode(" y el de P2 es "));
    out.appendChild(tex("\\omega_2(" + (i + 1) + "," + (j + 1) + ") = " + PAY2[i][j]));
    out.appendChild(document.createTextNode("."));
    App.$("#road-status").textContent = (!S.swerve1 && !S.swerve2) ? "¡Choque!" : "Fin de la partida.";
    App.$("#btn-replay").disabled = false;
  }

  /* ---------------------------------------------------------------- */
  /* ¿Equilibrio de Nash? (comprobación generada desde las matrices)   */
  /* ---------------------------------------------------------------- */
  function showNE() {
    const [is, js] = S.pair;           // índices 0/1
    const I = is + 1, Jx = js + 1;     // índices 1/2 para la notación
    const io = 1 - is, jo = 1 - js;    // la otra estrategia
    const out = clear(App.$("#chicken-ne"));
    out.classList.add("reveal");

    const header = (is === js)
      ? "i^* = j^* = " + I
      : "i^* = " + I + ",\\; j^* = " + Jx;
    out.appendChild(tex(header, true));
    const sub = el("div", { class: "ne-sub", text: "(\\(P_1\\) " + STRAT[is] + ", \\(P_2\\) " + STRAT[js] + ")" });
    out.appendChild(sub);
    App.renderMathIn(sub);

    // 1.ª condición: el jugador 1 no gana desviándose
    const a1 = PAY1[io][js], b1 = PAY1[is][js];
    const ok1 = a1 <= b1;
    out.appendChild(el("div", { class: "ne-step", text: "1.ª condición" }));
    out.appendChild(tex("\\omega_1(i, j^*) \\le \\omega_1(i^*, j^*),\\quad \\forall i = 1,2", true));
    out.appendChild(tex("\\omega_1(" + (io + 1) + "," + Jx + ") \\le \\omega_1(" + I + "," + Jx + ")", true));
    const l1 = el("div", { class: "ne-line" }, [tex(a1 + " \\le " + b1), App.badge(ok1)]);
    out.appendChild(l1);

    let ok2 = null;
    if (ok1) {
      // 2.ª condición: el jugador 2 no gana desviándose
      const a2 = PAY2[is][jo], b2 = PAY2[is][js];
      ok2 = a2 <= b2;
      out.appendChild(el("div", { class: "ne-step", text: "2.ª condición" }));
    out.appendChild(tex("\\omega_2(i^*, j) \\le \\omega_2(i^*, j^*),\\quad \\forall j = 1,2", true));
      out.appendChild(tex("\\omega_2(" + I + "," + (jo + 1) + ") \\le \\omega_2(" + I + "," + Jx + ")", true));
      out.appendChild(el("div", { class: "ne-line" }, [tex(a2 + " \\le " + b2), App.badge(ok2)]));
    }

    const isNE = ok1 && ok2;
    out.appendChild(el("div", {
      class: "verdict " + (isNE ? "yes" : "no"),
      text: isNE ? "Esta combinación de estrategias es un equilibrio de Nash." : "Esta combinación de estrategias no es un equilibrio de Nash.",
    }));
  }

  App.registerTab(3, { init, onShow });
})();
