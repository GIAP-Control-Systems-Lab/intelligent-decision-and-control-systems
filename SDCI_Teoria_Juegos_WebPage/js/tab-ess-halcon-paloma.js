/* 06 · Ejemplo 2 ESS: juego halcón-paloma (H-D). */
(function () {
  "use strict";
  const { el, svg, tex, clear, f2 } = App;

  const COL_H = "#5C3DEE", COL_D = "#15C28C";
  let sV, sC, labV, labC, pie, legend, piStar;

  function init() {
    buildMatrix();
    sV = App.$("#slider-v");
    sC = App.$("#slider-c");
    labV = App.$("#label-v");
    labC = App.$("#label-c");
    pie = App.$("#hd-pie");
    legend = App.$("#hd-legend");
    piStar = App.$("#hd-pistar");
    sV.addEventListener("input", update);
    sC.addEventListener("input", update);
    update();
  }

  function buildMatrix() {
    const vals = [["\\dfrac{V-C}{2}", "V"], ["0", "\\dfrac{V}{2}"]];
    const lab = ["Halcón", "Paloma"];
    const icon = ["assets/img/hawk.png", "assets/img/dove.png"];
    const t = el("table", { class: "matrix" });
    const hr = el("tr");
    hr.appendChild(el("th"));
    lab.forEach((l, j) => hr.appendChild(el("th", { scope: "col", class: "icon-head" }, [
      el("img", { src: icon[j], alt: "" }),
      el("span", { class: "head", text: "P2 " + l }),
    ])));
    t.appendChild(hr);
    vals.forEach((row, i) => {
      const tr = el("tr");
      tr.appendChild(el("th", { scope: "row", class: "icon-head" }, [
        el("img", { src: icon[i], alt: "" }),
        el("span", { class: "head", text: "P1 " + lab[i] }),
      ]));
      row.forEach(v => {
        const c = el("div", { class: "cell", style: "min-width: 92px; height: 64px;" });
        c.appendChild(tex(v));
        tr.appendChild(el("td", null, [c]));
      });
      t.appendChild(tr);
    });
    App.$("#hd-matrix").appendChild(t);
  }

  function setTrack(input) {
    const min = +input.min, max = +input.max, v = +input.value;
    input.style.setProperty("--pct", ((v - min) / (max - min) * 100) + "%");
  }

  function update() {
    const V = parseFloat(sV.value);
    const C = parseFloat(sC.value);
    labV.textContent = "V = " + V.toFixed(2);
    labC.textContent = "C = " + C.toFixed(2);
    setTrack(sV); setTrack(sC);

    // Proporción de halcones en el ESS: p = V/C, acotada a 1 (misma regla que la app original)
    let p = C !== 0 ? V / C : 0;
    if (p > 1) p = 1;
    // Redondeo para mostrar: la segunda componente es 1 menos la primera ya redondeada (suman 1.00)
    const pr = Math.round(p * 100) / 100;
    drawPie(p, 1 - p, pr);

    if (V >= C) {
      App.renderTex(piStar,
        "V \\ge C \\;\\Rightarrow\\; \\pi^* = [1,\\ 0] \\quad \\text{(halcón puro)}", false);
    } else {
      App.renderTex(piStar,
        "V < C \\;\\Rightarrow\\; \\pi^* = \\left[\\tfrac{V}{C},\\, \\tfrac{C-V}{C}\\right] = [" + f2(pr) + ",\\ " + f2(1 - pr) + "]", false);
    }
  }

  function arcPath(cx, cy, r, a0, a1) {
    const x0 = cx + r * Math.cos(a0), y0 = cy + r * Math.sin(a0);
    const x1 = cx + r * Math.cos(a1), y1 = cy + r * Math.sin(a1);
    const large = (a1 - a0) > Math.PI ? 1 : 0;
    return "M" + cx + " " + cy + " L" + x0 + " " + y0 + " A" + r + " " + r + " 0 " + large + " 1 " + x1 + " " + y1 + " Z";
  }

  function drawPie(h, d, hr) {
    const dr = 1 - hr;
    clear(pie);
    const cx = 110, cy = 110, r = 100;
    const start = -Math.PI / 2;           // empieza arriba, sentido horario
    const slices = [{ v: h, c: COL_H }, { v: d, c: COL_D }];
    let a = start;
    slices.forEach(s => {
      if (s.v <= 1e-9) return;
      if (s.v >= 1 - 1e-9) {
        pie.appendChild(svg("circle", { cx, cy, r, fill: s.c }));
      } else {
        const a1 = a + s.v * 2 * Math.PI;
        pie.appendChild(svg("path", { d: arcPath(cx, cy, r, a, a1), fill: s.c, stroke: "#fff", "stroke-width": 3, "stroke-linejoin": "round" }));
        a = a1;
      }
    });
    // Agujero central
    pie.appendChild(svg("circle", { cx, cy, r: 52, fill: "#fff" }));
    const t1 = svg("text", { x: cx, y: cy - 4, "text-anchor": "middle", "font-family": "Bricolage Grotesque, sans-serif", "font-size": 30, "font-weight": 700, fill: COL_H });
    t1.textContent = f2(hr);
    const t2 = svg("text", { x: cx, y: cy + 20, "text-anchor": "middle", "font-family": "Figtree, sans-serif", "font-size": 13, "font-weight": 600, fill: "#4B4866" });
    t2.textContent = "Halcón";
    pie.appendChild(t1);
    pie.appendChild(t2);
    pie.setAttribute("aria-label", "Estrategia mixta del jugador 1: Halcón " + f2(hr) + ", Paloma " + f2(dr));

    clear(legend);
    [["Halcón", hr, COL_H], ["Paloma", dr, COL_D]].forEach(([n, v, c]) => {
      legend.appendChild(el("div", { class: "row" }, [
        el("span", { class: "sw", style: "background:" + c }),
        el("span", { text: n }),
        el("span", { class: "val", text: f2(v) }),
      ]));
    });
  }

  App.registerTab(6, { init });
})();
