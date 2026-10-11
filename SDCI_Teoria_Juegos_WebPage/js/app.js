/* Navegación entre pestañas e inicialización. */
(function () {
  "use strict";

  const tabs = Array.from(document.querySelectorAll('[role="tab"]'));
  const panels = tabs.map(t => document.getElementById(t.getAttribute("aria-controls")));

  function select(index, focus) {
    tabs.forEach((t, k) => {
      const on = k === index;
      t.setAttribute("aria-selected", on ? "true" : "false");
      t.tabIndex = on ? 0 : -1;
      panels[k].hidden = !on;
    });
    if (focus) tabs[index].focus();
    tabs[index].scrollIntoView({ block: "nearest", inline: "nearest" });
    const def = App.tabs[index + 1];
    if (def && def.onShow) def.onShow();
    App.storage.set("hsi-tab", String(index));
    if (history.replaceState) history.replaceState(null, "", "#ejemplo-" + (index + 1));
  }

  tabs.forEach((t, k) => {
    t.addEventListener("click", () => {
      select(k, false);
      const top = document.querySelector(".tabs-wrap").offsetTop;
      if (window.scrollY > top) window.scrollTo({ top, behavior: "smooth" });
    });
    t.addEventListener("keydown", e => {
      let n = null;
      if (e.key === "ArrowRight") n = (k + 1) % tabs.length;
      if (e.key === "ArrowLeft") n = (k - 1 + tabs.length) % tabs.length;
      if (e.key === "Home") n = 0;
      if (e.key === "End") n = tabs.length - 1;
      if (n !== null) { e.preventDefault(); select(n, true); }
    });
  });

  // Año del copyright
  const yr = document.getElementById("copy-year");
  if (yr) yr.textContent = String(new Date().getFullYear());

  // Inicializar todas las pestañas
  Object.keys(App.tabs).forEach(k => {
    const def = App.tabs[k];
    try { def.init(); def.initialized = true; }
    catch (err) { console.error("Error al iniciar la pestaña " + k, err); }
  });

  // Renderizar la notación matemática estática del documento
  App.renderMathIn(document.body);

  // Pestaña inicial: #ejemplo-N en la URL, o la última visitada
  let start = 0;
  const m = /^#ejemplo-(\d)$/.exec(location.hash);
  if (m) start = Math.min(Math.max(+m[1] - 1, 0), tabs.length - 1);
  else {
    const saved = parseInt(App.storage.get("hsi-tab"), 10);
    if (!isNaN(saved) && saved >= 0 && saved < tabs.length) start = saved;
  }
  select(start, false);
  window.scrollTo(0, 0);

  window.addEventListener("hashchange", () => {
    const h = /^#ejemplo-(\d)$/.exec(location.hash);
    if (h) select(Math.min(Math.max(+h[1] - 1, 0), tabs.length - 1), false);
  });
})();
