// Shared drawing rig for every scene: people, watches, bag. Deterministic, no randomness.
window.HC = (function () {
  const PEOPLE = {
    pai: { skin: "#e0a77a", hair: "#3b2a20", style: "short", shirt: "#2f8f5b", pants: "#2b3a55", shoe: "#1b1b1b", stache: true },
    mae: { skin: "#c98a62", hair: "#5a2e1a", style: "long", shirt: "#e85d75", pants: "#c98a62", shoe: "#7a2333", skirt: "#b8405a" },
    filho: { skin: "#e8b48c", hair: "#2a1c14", style: "kid", shirt: "#ffb627", pants: "#3d6fd6", shoe: "#ffffff" },
    atendente: { skin: "#b77a52", hair: "#1c1c1c", style: "short", shirt: "#ffffff", pants: "#1d2433", shoe: "#111111", vest: "#123a8f" },
  };

  const HAIR = {
    short: (c) => `<path d="M52 112 Q52 56 100 58 Q148 56 148 112 Q142 82 100 80 Q60 82 52 112Z" fill="${c}"/>`,
    long: (c) =>
      `<path d="M50 112 Q48 54 100 56 Q152 54 150 112 L154 210 Q140 222 130 204 L134 112 Q122 84 100 84 Q78 84 66 112 L70 204 Q60 222 46 210Z" fill="${c}"/>`,
    kid: (c) =>
      `<path d="M52 110 Q50 58 100 58 Q150 58 148 110 Q140 80 112 80 L118 64 L100 78 L92 60 L84 80 Q60 84 52 110Z" fill="${c}"/>`,
  };

  function person(kind) {
    const c = PEOPLE[kind];
    const legs = (x) =>
      `<rect x="${x}" y="296" width="28" height="214" rx="12" fill="${c.pants}"/><ellipse cx="${x + 12}" cy="514" rx="26" ry="13" fill="${c.shoe}"/>`;
    const arm = (x) =>
      `<rect x="${x}" y="176" width="24" height="142" rx="12" fill="${c.shirt}"/><circle cx="${x + 12}" cy="322" r="14" fill="${c.skin}"/>`;
    const vest = c.vest
      ? `<path d="M58 196 Q58 168 84 168 L96 240 L96 318 L58 318Z" fill="${c.vest}"/><path d="M142 196 Q142 168 116 168 L104 240 L104 318 L142 318Z" fill="${c.vest}"/>
         <path d="M88 172 L100 182 L112 172 L112 192 L100 184 L88 192Z" fill="#ffc83d"/><rect x="114" y="226" width="22" height="12" rx="3" fill="#ffc83d"/>`
      : "";
    const skirt = c.skirt ? `<path d="M56 286 L144 286 L164 404 L36 404Z" fill="${c.skirt}"/>` : "";
    const stache = c.stache ? `<path d="M84 131 Q100 122 116 131 Q100 137 84 131Z" fill="${c.hair}"/>` : "";
    return `<svg viewBox="0 0 200 540" width="100%" height="100%" overflow="visible" aria-hidden="true">
      <g class="body">
        <g class="leg leg-l">${legs(70)}</g><g class="leg leg-r">${legs(102)}</g>
        <rect x="58" y="166" width="84" height="152" rx="28" fill="${c.shirt}"/>${vest}${skirt}
        <g class="arm arm-l">${arm(36)}</g><g class="arm arm-r">${arm(140)}</g>
        <rect x="88" y="148" width="24" height="28" fill="${c.skin}"/>
        <g class="head">
          <circle cx="54" cy="114" r="10" fill="${c.skin}"/><circle cx="146" cy="114" r="10" fill="${c.skin}"/>
          <circle cx="100" cy="112" r="47" fill="${c.skin}"/>
          ${HAIR[c.style](c.hair)}
          <circle cx="76" cy="128" r="8" fill="#ff7a7a" opacity="0.35"/><circle cx="124" cy="128" r="8" fill="#ff7a7a" opacity="0.35"/>
          <g class="eyes"><ellipse cx="84" cy="112" rx="5" ry="6.5" fill="#1d1d1d"/><ellipse cx="116" cy="112" rx="5" ry="6.5" fill="#1d1d1d"/></g>
          <path d="M76 98 Q84 93 92 98 M108 98 Q116 93 124 98" stroke="${c.hair}" stroke-width="4" fill="none" stroke-linecap="round"/>
          ${stache}
          <path class="smile" d="M86 136 Q100 150 114 136" stroke="#5a1f1f" stroke-width="4.5" fill="none" stroke-linecap="round"/>
          <ellipse class="mouth-open" cx="100" cy="140" rx="10" ry="8" fill="#6b1d1d" opacity="0"/>
        </g>
      </g></svg>`;
  }

  // strap / case / face colours
  const WATCHES = {
    azul: ["#1e4fd8", "#e6ebf5", "url(#hc-blueface)"],
    prata: ["#5d6675", "#d9dde6", "#f7f7f4"],
    ouro: ["#7a4e1d", "#f0c45a", "#fff6dc"],
    preto: ["#1b1b1f", "#2c2c33", "#111114"],
    rose: ["#d98a8a", "#f2c2b3", "#fff1ee"],
  };
  function watch(kind) {
    const [strap, cs, face] = WATCHES[kind];
    let ticks = "";
    for (let i = 0; i < 12; i++) {
      const a = (i * Math.PI) / 6, r1 = i % 3 ? 48 : 42;
      ticks += `<line x1="${100 + Math.sin(a) * r1}" y1="${160 - Math.cos(a) * r1}" x2="${100 + Math.sin(a) * 54}" y2="${160 - Math.cos(a) * 54}" stroke="${kind === "preto" || kind === "azul" ? "#ffffff" : "#333"}" stroke-width="${i % 3 ? 3 : 6}" stroke-linecap="round"/>`;
    }
    const hand = kind === "preto" || kind === "azul" ? "#ffffff" : "#222";
    return `<svg viewBox="0 0 200 320" width="100%" height="100%" overflow="visible" aria-hidden="true">
      <defs><radialGradient id="hc-blueface" cx="40%" cy="35%" r="75%"><stop offset="0" stop-color="#3f8cff"/><stop offset="0.6" stop-color="#1446c8"/><stop offset="1" stop-color="#0a2477"/></radialGradient></defs>
      <rect x="68" y="0" width="64" height="112" rx="12" fill="${strap}"/><rect x="68" y="208" width="64" height="112" rx="12" fill="${strap}"/>
      <rect x="166" y="148" width="16" height="24" rx="4" fill="${cs}"/>
      <circle cx="100" cy="160" r="72" fill="${cs}"/><circle cx="100" cy="160" r="60" fill="${face}"/>
      ${ticks}
      <g class="hand-h"><rect x="96" y="124" width="8" height="40" rx="4" fill="${hand}"/></g>
      <g class="hand-m"><rect x="97.5" y="108" width="5" height="56" rx="2.5" fill="${kind === "azul" ? "#ffc83d" : hand}"/></g>
      <circle cx="100" cy="160" r="7" fill="#ffc83d"/>
      <path d="M58 130 Q70 104 100 98" stroke="#ffffff" stroke-width="6" fill="none" opacity="0.35" stroke-linecap="round"/>
    </svg>`;
  }

  function bag() {
    return `<svg viewBox="0 0 200 240" width="100%" height="100%" overflow="visible" aria-hidden="true">
      <path d="M64 70 Q64 18 100 18 Q136 18 136 70" stroke="#0b1f4d" stroke-width="10" fill="none"/>
      <rect x="20" y="64" width="160" height="172" rx="10" fill="#1e6bff"/><rect x="20" y="64" width="160" height="22" fill="#1557d8"/>
      <circle cx="100" cy="142" r="34" fill="none" stroke="#ffc83d" stroke-width="7"/>
      <path d="M100 124 L100 142 L114 150" stroke="#ffffff" stroke-width="7" fill="none" stroke-linecap="round"/>
      <text data-layout-ignore x="100" y="208" text-anchor="middle" font-family="Archivo Black" font-size="17" fill="#ffffff">HORA DE COMPRAR</text>
    </svg>`;
  }

  // Fill every [data-hc] placeholder once.
  function mount() {
    document.querySelectorAll("[data-hc]").forEach((el) => {
      if (el.firstElementChild) return;
      const [type, kind] = el.dataset.hc.split(":");
      el.innerHTML = type === "person" ? person(kind) : type === "watch" ? watch(kind) : bag();
    });
  }

  // A walk cycle of `steps` strides over [start, start + dur).
  function walk(tl, sel, start, dur) {
    const steps = Math.max(2, Math.round(dur / 0.42));
    const s = dur / steps;
    for (let i = 0; i < steps; i++) {
      const d = i % 2 ? 1 : -1, t = start + i * s;
      tl.to(`${sel} .leg-l`, { rotation: 18 * d, transformOrigin: "50% 0%", duration: s, ease: "sine.inOut" }, t);
      tl.to(`${sel} .leg-r`, { rotation: -18 * d, transformOrigin: "50% 0%", duration: s, ease: "sine.inOut" }, t);
      tl.to(`${sel} .arm-l`, { rotation: -14 * d, transformOrigin: "50% 4%", duration: s, ease: "sine.inOut" }, t);
      tl.to(`${sel} .arm-r`, { rotation: -14 * d, transformOrigin: "50% 4%", duration: s, ease: "sine.inOut" }, t + 0.03);
      tl.to(`${sel} .body`, { y: -10, duration: s / 2, ease: "sine.out" }, t);
      tl.to(`${sel} .body`, { y: 0, duration: s / 2, ease: "sine.in" }, t + s / 2);
    }
    tl.to(`${sel} .leg, ${sel} .arm-l, ${sel} .arm-r`, { rotation: 0, duration: 0.25, ease: "power2.out" }, start + dur);
  }

  // Lip flaps over [start, start + dur), pattern fixed so every render matches.
  function talk(tl, sel, start, dur) {
    const n = Math.floor(dur / 0.13);
    tl.set(`${sel} .smile`, { opacity: 0 }, start);
    tl.set(`${sel} .mouth-open`, { opacity: 1 }, start);
    for (let i = 0; i < n; i++) {
      const open = 0.35 + 0.65 * Math.abs(Math.sin(i * 1.7));
      tl.to(`${sel} .mouth-open`, { scaleY: i % 2 ? 0.25 : open, transformOrigin: "50% 50%", duration: 0.12, ease: "none" }, start + i * 0.13);
    }
    tl.set(`${sel} .mouth-open`, { opacity: 0 }, start + dur);
    tl.set(`${sel} .smile`, { opacity: 1 }, start + dur);
  }

  function blink(tl, sel, times) {
    times.forEach((t) => {
      tl.to(`${sel} .eyes`, { scaleY: 0.1, transformOrigin: "50% 50%", duration: 0.06 }, t);
      tl.to(`${sel} .eyes`, { scaleY: 1, duration: 0.08 }, t + 0.08);
    });
  }

  // Watch hands sweep: deterministic, timeline-driven.
  function tick(tl, sel, start, dur) {
    tl.fromTo(`${sel} .hand-m`, { rotation: 60 }, { rotation: 60 + dur * 60, svgOrigin: "100 160", duration: dur, ease: "none" }, start);
    tl.fromTo(`${sel} .hand-h`, { rotation: 300 }, { rotation: 300 + dur * 5, svgOrigin: "100 160", duration: dur, ease: "none" }, start);
  }

  return { mount, walk, talk, blink, tick };
})();
