/* 04 · Ejemplo Juegos Simétricos: dividir o robar. */
(function () {
  "use strict";
  const { el, tex, clear } = App;

  const SPLIT = "Dividir", STEAL = "Robar";
  const LABELS = [SPLIT, STEAL];
  const PAY1 = [["5000", "0"], ["10000", "0"]];
  const PAY2 = [["5000", "10000"], ["0", "0"]];
  const IDX = { [SPLIT]: 0, [STEAL]: 1 };

  const S = {
    titForTat: false,        // false: oponente 1 (azar), true: oponente 2 (estrategia fija)
    lastUserPlayed: null,
  };

  let btnPlay, btnReplay, btnReveal, btnChange, bubble, avatar, outcome, oppTag;

  function init() {
    btnPlay = App.$("#btn-pd-play");
    btnReplay = App.$("#btn-pd-replay");
    btnReveal = App.$("#btn-pd-reveal");
    btnChange = App.$("#btn-pd-change");
    bubble = App.$("#pd-bubble");
    avatar = App.$("#pd-avatar");
    outcome = App.$("#pd-outcome");
    oppTag = App.$("#pd-opp-tag");

    // Las matrices se muestran después de la primera jugada.
    [App.$("#pd-m1"), App.$("#pd-m2")].forEach(h =>
      h.appendChild(el("div", { class: "matrix-empty", text: "Piense primero cómo se ve esta matriz. Se mostrará al jugar." })));

    btnPlay.addEventListener("click", onSubmit);
    btnReplay.addEventListener("click", replay);
    btnReveal.addEventListener("click", reveal);
    btnChange.addEventListener("click", changeOpponent);
  }

  function userChoice() {
    const r = document.querySelector('input[name="pd-choice"]:checked');
    return r && r.value === "robar" ? STEAL : SPLIT;
  }

  function computerChoice() {
    if (S.titForTat) {
      // Ojo por ojo: empieza dividiendo y luego repite la última jugada del usuario
      return S.lastUserPlayed ? S.lastUserPlayed : SPLIT;
    }
    return Math.random() < 0.5 ? SPLIT : STEAL;
  }

  function outcomeText(u, c) {
    if (u === SPLIT && c === SPLIT) return "Ambos decidieron " + SPLIT + ": ¡Ambos ganaron!";
    if (u === SPLIT && c === STEAL) return "Usted decidió " + SPLIT + ", el jugador 2 decidió " + STEAL + ": ¡Usted perdió todo el dinero! :(";
    if (u === STEAL && c === SPLIT) return "Usted decidió " + STEAL + ", el jugador 2 decidió " + SPLIT + ": ¡Usted ganó todo el dinero! :)";
    return "Ambos decidieron " + STEAL + ": ¡Ambos perdieron!";
  }

  function displayMatrix(host, pay, selected) {
    clear(host);
    const t = el("table", { class: "matrix reveal" });
    const hr = el("tr");
    hr.appendChild(el("th", { class: "axis-label", style: "font-size:.7rem" }, [el("span", { class: "axis-p1", text: "J1" }), " \\ ", el("span", { class: "axis-p2", text: "J2" })]));
    LABELS.forEach(l => hr.appendChild(el("th", { scope: "col" }, [el("span", { class: "head", text: l })])));
    t.appendChild(hr);
    pay.forEach((row, i) => {
      const tr = el("tr");
      tr.appendChild(el("th", { scope: "row" }, [el("span", { class: "head", text: LABELS[i] })]));
      row.forEach((v, j) => {
        const pick = selected && selected[0] === i && selected[1] === j;
        const c = el("div", { class: "cell" + (pick ? " is-pick" : "") });
        c.appendChild(tex(v));
        tr.appendChild(el("td", null, [c]));
      });
      t.appendChild(tr);
    });
    host.appendChild(t);
  }

  function setChoicesDisabled(d) {
    document.querySelectorAll('input[name="pd-choice"]').forEach(r => { r.disabled = d; });
  }

  function onSubmit() {
    const u = userChoice();
    const c = computerChoice();
    S.lastUserPlayed = u;
    outcome.textContent = "El jugador 2 eligió: " + c + "\n" + outcomeText(u, c);
    outcome.classList.remove("reveal"); void outcome.offsetWidth; outcome.classList.add("reveal");
    const sel = [IDX[u], IDX[c]];
    displayMatrix(App.$("#pd-m1"), PAY1, sel);
    displayMatrix(App.$("#pd-m2"), PAY2, sel);
    btnPlay.disabled = true;
    btnReveal.disabled = true;
    btnReplay.disabled = false;
    setChoicesDisabled(true);
  }

  function replay() {
    clear(outcome);
    bubble.textContent = "";
    bubble.classList.remove("is-talking");
    btnPlay.disabled = false;
    if (!S.titForTat) btnReveal.disabled = false;
    btnReplay.disabled = true;
    setChoicesDisabled(false);
    displayMatrix(App.$("#pd-m1"), PAY1, null);
    displayMatrix(App.$("#pd-m2"), PAY2, null);
  }

  function reveal() {
    // Puede mentir: 3 de cada 4 veces dice que va a dividir
    const options = ["Voy a dividir", "Voy a dividir", "Voy a dividir", "Voy a robar"];
    bubble.textContent = options[Math.floor(Math.random() * options.length)];
    bubble.classList.add("is-talking");
  }

  function changeOpponent() {
    S.titForTat = !S.titForTat;
    bubble.textContent = "";
    bubble.classList.remove("is-talking");
    if (S.titForTat) {
      avatar.src = "assets/img/person2.png";
      btnReveal.disabled = true;
      btnReveal.hidden = true;
      oppTag.textContent = "Oponente 2 de 2";
      S.lastUserPlayed = null;
    } else {
      avatar.src = "assets/img/person.png";
      btnReveal.hidden = false;
      btnReveal.disabled = !btnPlay.disabled ? false : true;
      oppTag.textContent = "Oponente 1 de 2";
    }
  }

  App.registerTab(4, { init });
})();
