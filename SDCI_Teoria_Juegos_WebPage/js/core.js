/* Shared helpers. Everything runs client-side: no server is involved. */
(function () {
  "use strict";

  const SVG_NS = "http://www.w3.org/2000/svg";

  const App = {
    tabs: {},           // index -> { init, onShow, initialized }

    registerTab(index, def) {
      this.tabs[index] = Object.assign({ initialized: false }, def);
    },

    $(sel, root) { return (root || document).querySelector(sel); },

    /** Create an HTML element: el("div", {class: "x"}, [children]) */
    el(tag, attrs, children) {
      const node = document.createElement(tag);
      App._apply(node, attrs, children);
      return node;
    },

    /** Create an SVG element. */
    svg(tag, attrs, children) {
      const node = document.createElementNS(SVG_NS, tag);
      App._apply(node, attrs, children);
      return node;
    },

    _apply(node, attrs, children) {
      if (attrs) {
        for (const [k, v] of Object.entries(attrs)) {
          if (v === null || v === undefined || v === false) continue;
          if (k === "text") node.textContent = v;
          else if (k === "html") node.innerHTML = v;
          else if (k.startsWith("on") && typeof v === "function") node.addEventListener(k.slice(2), v);
          else node.setAttribute(k, v === true ? "" : v);
        }
      }
      if (children) {
        for (const c of [].concat(children)) {
          if (c === null || c === undefined) continue;
          node.appendChild(typeof c === "string" ? document.createTextNode(c) : c);
        }
      }
    },

    /** Render a LaTeX string into a new <span> (or <div> for display mode). */
    tex(latex, display) {
      const node = document.createElement(display ? "div" : "span");
      App.renderTex(node, latex, display);
      return node;
    },

    renderTex(node, latex, display) {
      if (window.katex) {
        try {
          window.katex.render(latex, node, {
            displayMode: !!display,
            throwOnError: false,
            strict: "ignore",
            output: "htmlAndMathml",
          });
          return node;
        } catch (e) { /* fall through to plain text */ }
      }
      node.textContent = latex;
      return node;
    },

    /** Render \( \) and \[ \] delimiters inside an element. */
    renderMathIn(node) {
      if (window.renderMathInElement) {
        window.renderMathInElement(node, {
          delimiters: [
            { left: "\\[", right: "\\]", display: true },
            { left: "\\(", right: "\\)", display: false },
          ],
          throwOnError: false,
          strict: "ignore",
        });
      }
    },

    /** Number with 2 decimals, avoiding "-0.00". */
    f2(x) {
      const s = (Math.round(x * 100) / 100).toFixed(2);
      return s === "-0.00" ? "0.00" : s;
    },

    /** Inline check / cross badge. */
    badge(ok) {
      const span = App.el("span", { class: "check " + (ok ? "yes" : "no") });
      const icon = ok
        ? '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="11" fill="currentColor"/><path d="M7 12.5l3.2 3.2L17 9" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>'
        : '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="11" fill="currentColor"/><path d="M8 8l8 8M16 8l-8 8" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round"/></svg>';
      span.innerHTML = icon + "<span>" + (ok ? "Se cumple" : "No se cumple") + "</span>";
      return span;
    },

    clear(node) { while (node.firstChild) node.removeChild(node.firstChild); return node; },

    storage: {
      get(key) { try { return window.localStorage.getItem(key); } catch (e) { return null; } },
      set(key, val) { try { window.localStorage.setItem(key, val); } catch (e) { /* ignore */ } },
    },
  };

  window.App = App;
})();
