// trend-card: daily-trend charts drawn from Home Assistant long-term statistics.
//
//   mode: centred  Up to two series, each on its own axis (left, right),
//                  centred on the series' mean over the window. The line is
//                  the raw readings, or with smooth_days a trailing moving
//                  average over the readings drawn as dots.
//                  span: percent -> both axes cover the same ±% of their mean
//                  span: absolute -> both axes cover the same ± in units
//                  An entity with `split: above|below` is a shared scale: its
//                  weigh-ins are labelled by a boundary that starts at
//                  split_boundary and then follows the midpoint of the upper
//                  side's p25 and the lower side's p75 over the last
//                  split_learn_days.
//   mode: banded   One series of daily totals as bars. Bars within
//                  ±band_width of the window median are "ok", others "bad".
//
// Styling comes from theme variables, so the card follows the HA theme.

const DAY = 86400000;
const XMLNS = "http://www.w3.org/2000/svg";

const dayStart = (t) => {
  const d = new Date(t);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
};

const mean = (xs) => xs.reduce((a, b) => a + b, 0) / xs.length;

const median = (xs) => {
  const a = [...xs].sort((x, y) => x - y);
  const m = a.length >> 1;
  return a.length % 2 ? a[m] : (a[m - 1] + a[m]) / 2;
};

// One slot per local day, oldest first; the last slot is today.
export function daySlots(now, days) {
  const today = dayStart(now);
  return Array.from({ length: days }, (_, i) => dayStart(today - (days - 1 - i) * DAY + DAY / 2));
}

// Hourly statistics rows -> daily totals, one per day slot (null where no
// data): the max of the hourly end state, since the counter resets at midnight.
export function dailyTotals(rows, slots) {
  const index = new Map(slots.map((s, i) => [s, i]));
  const buckets = slots.map(() => []);
  for (const row of rows || []) {
    const i = index.get(dayStart(row.start));
    if (i !== undefined && row.state != null) buckets[i].push(row.state);
  }
  return buckets.map((b) => (b.length ? Math.max(...b) : null));
}

// Trailing moving average of readings, one point per day slot (at midday)
// that has readings in the `days` up to the end of that day.
export function movingAverage(readings, slots, days) {
  return slots.flatMap((s) => {
    const end = s + DAY;
    const vs = readings.filter((r) => r.t >= end - days * DAY && r.t < end).map((r) => r.v);
    return vs.length ? [{ t: s + DAY / 2, v: mean(vs) }] : [];
  });
}

// Readings from a weight sensor's hourly statistics. The sensor keeps its last
// value, so every hour repeats the previous reading; only values that differ
// from the previous hour's min/max count as new readings.
export function weighIns(rows) {
  const out = [];
  let prev = [];
  for (const row of rows || []) {
    const vs = [...new Set([row.min, row.max])].filter((v) => v != null);
    for (const v of vs) if (!prev.includes(v)) out.push({ t: new Date(row.start).getTime(), v });
    prev = vs;
  }
  return out;
}

// Label each weigh-in "above" or "below" a boundary. The boundary starts at
// `initial`; once both sides have MIN_LEARN readings in the last `learnDays`,
// it is the midpoint of the upper side's 25th percentile and the lower side's
// 75th percentile over that period: the facing quartiles, so a single stray
// reading (a half step, someone holding a cat) can't drag it.
const MIN_LEARN = 3;
const quantile = (xs, q) => {
  const a = [...xs].sort((x, y) => x - y);
  const i = (a.length - 1) * q;
  const lo = Math.floor(i);
  return a[lo] + (a[Math.min(lo + 1, a.length - 1)] - a[lo]) * (i - lo);
};
export function splitWeighIns(readings, initial, learnDays) {
  const out = [];
  const win = { above: [], below: [] };
  for (const r of readings) {
    for (const side of ["above", "below"]) {
      while (win[side].length && win[side][0].t < r.t - learnDays * DAY) win[side].shift();
    }
    const learned = win.above.length >= MIN_LEARN && win.below.length >= MIN_LEARN;
    const boundary = learned
      ? (quantile(win.above.map((x) => x.v), 0.25) + quantile(win.below.map((x) => x.v), 0.75)) / 2
      : initial;
    const side = r.v >= boundary ? "above" : "below";
    win[side].push(r);
    out.push({ ...r, side, boundary });
  }
  return out;
}

// Per-trace centre and half-range for the centred chart: centred on the mean
// of the line, wide enough to fit the line and the dots.
export function centredAxes(traces, span) {
  const stats = traces.map(({ line, dots }) => {
    if (!line.length) return null;
    const m = mean(line.map((p) => p.v));
    return { m, dev: Math.max(...[...line, ...dots].map((p) => Math.abs(p.v - m))) };
  });
  const live = stats.filter(Boolean);
  if (!live.length) return stats;
  const p = Math.max(...live.map((s) => s.dev / s.m), 0.005) * 1.15;
  const h = Math.max(...live.map((s) => s.dev), 0.1) * 1.15;
  const axes = stats.map((s) => s && roundAxis(s.m, span === "absolute" ? h : s.m * p));
  if (span !== "absolute") return axes;
  // Same span on both axes, so they share the larger rounded half-range.
  const half = Math.max(...axes.filter(Boolean).map((a) => a.half));
  return axes.map((a) => a && { ...a, half });
}

// Round labels: whole numbers from 10 up, one decimal below. The centre snaps
// to that unit and the half-range rounds up to an even number of units, so
// all five gridlines (centre, ±half/2, ±half) land on round values.
function roundAxis(m, half) {
  const unit = Math.abs(m) >= 10 ? 1 : 0.1;
  const centre = Math.round(m / unit) * unit;
  const need = half + Math.abs(m - centre);
  return { centre, half: Math.max(1, Math.ceil(need / (2 * unit))) * 2 * unit, decimals: unit === 1 ? 0 : 1 };
}

const el = (tag, attrs = {}, text) => {
  const e = document.createElementNS(XMLNS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  if (text !== undefined) e.textContent = text;
  return e;
};

const STYLE = `
  :host { display: block; }
  ha-card { padding: 12px 14px 10px; }
  .hd { display: flex; align-items: center; gap: 8px; margin-bottom: 6px;
        font: 600 11px var(--ha-font-family-code, monospace);
        letter-spacing: .06em; text-transform: uppercase; color: var(--primary-text-color); }
  .leg { margin-left: auto; display: flex; gap: 12px; font-weight: 400; }
  .leg span { display: flex; align-items: center; gap: 5px; }
  .leg i { width: 7px; height: 7px; display: inline-block; }
  .msg { font: 11px var(--ha-font-family-code, monospace); color: var(--secondary-text-color); padding: 8px 0; }
  svg { display: block; width: 100%; overflow: visible; }
  text { font-family: var(--ha-font-family-code, monospace); font-size: 9.5px; letter-spacing: .04em; }
  .mut { fill: var(--secondary-text-color); }
  .rule { stroke: var(--divider-color); stroke-width: 1; }
  .centre { stroke: var(--primary-text-color); stroke-dasharray: 2 3; stroke-width: .8; }
  .tick { stroke: var(--secondary-text-color); }
`;

class TrendCard extends HTMLElement {
  setConfig(config) {
    if (!["centred", "banded"].includes(config.mode)) throw new Error("mode must be 'centred' or 'banded'");
    const entities = (config.entities || []).map((e) => (typeof e === "string" ? { entity: e } : e));
    if (config.mode === "centred" && (entities.length < 1 || entities.length > 2))
      throw new Error("centred mode takes 1 or 2 entities");
    if (config.mode === "banded" && entities.length !== 1) throw new Error("banded mode takes exactly 1 entity");
    const colours = ["var(--primary-text-color)", "var(--accent-color)"];
    this._config = {
      days: 90,
      height: config.mode === "banded" ? 130 : 190,
      span: "percent",
      band_width: 2,
      split_boundary: 100,
      split_learn_days: 30,
      ...config,
      entities: entities.map((e, i) => ({ colour: colours[i], ...e })),
    };
    this._rows = null;
    this._error = null;
    if (!this.shadowRoot) {
      this.attachShadow({ mode: "open" }).innerHTML =
        `<style>${STYLE}</style><ha-card><div class="hd"></div><div class="body"></div></ha-card>`;
    }
    this._render();
    if (this._hass) this._fetch();
  }

  set hass(hass) {
    const old = this._hass;
    this._hass = hass;
    if (!this._config) return;
    const watched = this._config.entities.map((e) => e.entity);
    if (old && watched.every((id) => old.states[id] === hass.states[id])) return;
    // A watched entity changed: show the live value now, refresh history shortly.
    this._render();
    clearTimeout(this._debounce);
    this._debounce = setTimeout(() => this._fetch(), old ? 2000 : 0);
  }

  connectedCallback() {
    this._timer = setInterval(() => this._fetch(), 10 * 60 * 1000);
    this._onVisible = () => document.visibilityState === "visible" && this._fetch();
    document.addEventListener("visibilitychange", this._onVisible);
    this._resize = new ResizeObserver(() => this._render());
    this._resize.observe(this);
    this._render();
  }

  disconnectedCallback() {
    clearInterval(this._timer);
    clearTimeout(this._debounce);
    document.removeEventListener("visibilitychange", this._onVisible);
    this._resize?.disconnect();
  }

  async _fetch() {
    if (!this._hass || !this._config) return;
    const c = this._config;
    const slots = daySlots(Date.now(), c.days);
    // Splitting needs the month before the window to learn the boundary.
    // Splitting and smoothing need readings from before the window.
    const lead = Math.max(0, ...c.entities.map((e) => Math.max(e.split ? c.split_learn_days : 0, e.smooth_days || 0))) * DAY;
    try {
      const rows = await this._hass.callWS({
        type: "recorder/statistics_during_period",
        start_time: new Date(slots[0] - lead).toISOString(),
        statistic_ids: [...new Set(c.entities.map((e) => e.entity))],
        period: "hour",
        types: c.mode === "banded" ? ["state"] : ["mean", "min", "max"],
        ...(c.unit ? { units: { mass: c.unit } } : {}),
      });
      this._rows = rows;
      this._error = null;
    } catch (err) {
      this._error = err.message || String(err);
    }
    this._render();
  }

  _render() {
    const root = this.shadowRoot;
    if (!root || !this._config) return;
    const c = this._config;
    const hd = root.querySelector(".hd");
    const body = root.querySelector(".body");
    hd.innerHTML = "";
    hd.append(c.title || "");
    if (c.mode === "centred") {
      const leg = document.createElement("span");
      leg.className = "leg";
      for (const e of c.entities) {
        const s = document.createElement("span");
        s.innerHTML = `<i style="background:${e.colour}"></i>`;
        s.append(e.name || this._hass?.states[e.entity]?.attributes.friendly_name || e.entity);
        leg.append(s);
      }
      hd.append(leg);
    }
    body.innerHTML = "";
    if (this._error) return body.append(Object.assign(document.createElement("div"), { className: "msg", textContent: this._error }));
    if (!this._rows) return body.append(Object.assign(document.createElement("div"), { className: "msg", textContent: "LOADING…" }));
    const W = Math.max(body.clientWidth, 200);
    const svg = el("svg", { viewBox: `0 0 ${W} ${c.height}`, height: c.height });
    (c.mode === "centred" ? this._centred : this._banded).call(this, svg, W, c.height);
    body.append(svg);
  }

  _xLabels(svg, L, pw, H) {
    const d = this._config.days;
    [0, 1, 2, 3].forEach((k) => {
      const label = k === 3 ? (this._config.mode === "banded" ? "TODAY" : "NOW") : `-${Math.round(d - (d * k) / 3)}D`;
      svg.append(el("text", { x: L + (k / 3) * pw, y: H - 3, class: "mut", "text-anchor": ["start", "middle", "middle", "end"][k] }, label));
    });
  }

  _centred(svg, W, H) {
    const c = this._config;
    const slots = daySlots(Date.now(), c.days);
    const start = slots[0], now = Date.now();
    // Raw readings as the line, or with smooth_days: readings as dots and a
    // trailing moving average as the line, broken where a day has no average.
    const traces = c.entities.map((e) => {
      let readings = weighIns(this._rows[e.entity]);
      if (e.split) readings = splitWeighIns(readings, c.split_boundary, c.split_learn_days).filter((r) => r.side === e.split);
      const dots = readings.filter((r) => r.t >= start);
      if (!e.smooth_days) return { line: dots, dots: [], gap: Infinity };
      return { line: movingAverage(readings, slots, e.smooth_days), dots, gap: 1.5 * DAY };
    });
    const axes = centredAxes(traces, c.span);
    const L = 46, R = c.entities.length > 1 ? 46 : 12, top = 8, ph = H - top - 20, pw = W - L - R;
    const X = (t) => L + ((t - start) / (now - start)) * pw;
    for (const f of [-1, -0.5, 0, 0.5, 1]) {
      const y = top + ph / 2 - (f * ph) / 2;
      svg.append(el("line", { x1: L, x2: L + pw, y1: y, y2: y, class: f ? "rule" : "centre" }));
      c.entities.forEach((e, i) => {
        if (!axes[i]) return;
        const v = (axes[i].centre + f * axes[i].half).toFixed(axes[i].decimals);
        svg.append(el("text", {
          x: i ? L + pw + 6 : L - 6, y: y + 3, "text-anchor": i ? "start" : "end",
          ...(f ? { class: "mut" } : { fill: e.colour, "font-weight": 700 }),
        }, v));
      });
    }
    for (let k = 0; k <= 9; k++) {
      const x = L + (k / 9) * pw;
      svg.append(el("line", { x1: x, x2: x, y1: top + ph, y2: top + ph + 3, class: "tick" }));
    }
    traces.forEach(({ line, dots, gap }, i) => {
      const ax = axes[i];
      if (!ax) return;
      const Y = (v) => top + ph / 2 - ((v - ax.centre) / ax.half) * (ph / 2);
      const colour = c.entities[i].colour;
      for (const p of dots) svg.append(el("rect", { x: X(p.t) - 1.5, y: Y(p.v) - 1.5, width: 3, height: 3, fill: colour, opacity: 0.4 }));
      svg.append(el("path", {
        d: line.map((p, k) => `${k && p.t - line[k - 1].t <= gap ? "L" : "M"}${X(p.t).toFixed(1)} ${Y(p.v).toFixed(1)}`).join(""),
        fill: "none", stroke: colour, "stroke-width": 1.5,
      }));
    });
    this._xLabels(svg, L, pw, H);
  }

  _banded(svg, W, H) {
    const c = this._config;
    const e = c.entities[0];
    const slots = daySlots(Date.now(), c.days);
    const d = dailyTotals(this._rows[e.entity], slots);
    const live = parseFloat(this._hass?.states[e.entity]?.state);
    if (!Number.isNaN(live)) d[d.length - 1] = Math.max(d[d.length - 1] ?? 0, live);
    const complete = d.slice(0, -1).filter((v) => v != null);
    if (!complete.length) return svg.append(el("text", { x: 0, y: 14, class: "mut" }, "NO DATA YET"));
    const med = median(complete);
    const bw = c.band_width;
    const max = Math.max(med + bw + 1, ...d.filter((v) => v != null)) + 0.5;
    const L = 46, R = 50, top = 6, ph = H - top - 18, pw = W - L - R, st = pw / c.days;
    const Y = (v) => top + ph - (v / max) * ph;
    svg.append(el("rect", { x: L, y: Y(med + bw), width: pw, height: Y(Math.max(0, med - bw)) - Y(med + bw), fill: "var(--primary-text-color)", opacity: 0.05 }));
    for (const v of [0, Math.floor(max)]) {
      svg.append(el("line", { x1: L, x2: L + pw, y1: Y(v), y2: Y(v), class: "rule" }));
      svg.append(el("text", { x: L - 6, y: Y(v) + 3, class: "mut", "text-anchor": "end" }, v));
    }
    d.forEach((v, i) => {
      if (v == null) return;
      const today = i === d.length - 1;
      const ok = Math.abs(v - med) <= bw;
      const h = Math.max((v / max) * ph, 1.5);
      const attrs = { x: L + i * st + 0.7, y: top + ph - h, width: Math.max(st - 1.4, 1), height: h };
      svg.append(el("rect", today
        ? { ...attrs, fill: "none", stroke: "var(--primary-text-color)", "stroke-width": 1 }
        : { ...attrs, fill: ok ? "var(--success-color)" : "var(--error-color)" }));
    });
    svg.append(el("line", { x1: L, x2: L + pw, y1: Y(med), y2: Y(med), class: "centre" }));
    svg.append(el("text", { x: L + pw + 6, y: Y(med) + 3, "font-weight": 700, fill: "var(--primary-text-color)" }, `MED ${med}`));
    this._xLabels(svg, L, pw, H);
  }

  getCardSize() {
    return Math.ceil((this._config?.height || 190) / 50) + 1;
  }

  getGridOptions() {
    return { columns: 12, min_columns: 6 };
  }
}

if (typeof customElements !== "undefined" && !customElements.get("trend-card")) {
  customElements.define("trend-card", TrendCard);
  window.customCards = window.customCards || [];
  window.customCards.push({ type: "trend-card", name: "Trend card", description: "Mean-centred daily trends and banded daily totals." });
}
