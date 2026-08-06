// Radar panel: the same scored rooms as the Nearby panel, laid out as a
// 5x5 map of the ground around you with your own square in the middle.

const gridEl = document.getElementById("grid");
const offgridEl = document.getElementById("offgrid");
const terrainWrapEl = document.getElementById("terrain-wrap");
const terrainEl = document.getElementById("terrain");

const GRID_VECTORS = {
  n:  [0, -1],
  ne: [1, -1],
  e:  [1, 0],
  se: [1, 1],
  s:  [0, 1],
  sw: [-1, 1],
  w:  [-1, 0],
  nw: [-1, -1],
};

const GRID_RADIUS = 2;

// Orientation markers, drawn on the four outer mid-edge squares while they
// are empty. Free compass bearings that cost nothing when a room there has
// something in it.
const EDGE_LABELS = {
  "0,-2": "N",
  "2,0": "E",
  "0,2": "S",
  "-2,0": "W",
};

// Sum a direction string ("1 n", "1 n, 2 e") into a square. Returns null
// when the room has no place on a compass grid: vertical (u/d) and nautical
// (f/a/p/sb) directions have no square, anything beyond GRID_RADIUS falls
// off the edge, and a sum landing on the player's own square would be drawn
// over the centre marker. Those rooms are not dropped — the caller lists
// them below the grid.
function gridOffset(direction) {
  if (!direction) return null;
  let x = 0;
  let y = 0;
  for (const tok of direction.split(", ")) {
    const m = tok.match(/^(\d+) (\S+)$/);
    if (!m) return null;
    const vec = GRID_VECTORS[m[2]];
    if (!vec) return null;
    const steps = parseInt(m[1], 10);
    x += vec[0] * steps;
    y += vec[1] * steps;
  }
  if (Math.abs(x) > GRID_RADIUS || Math.abs(y) > GRID_RADIUS) return null;
  if (x === 0 && y === 0) return null;
  return { x, y };
}

// Background heat by absolute score, not relative to whatever else is on
// screen. Relative shading meant a square's colour depended on its
// neighbours: one NPC alone in view painted hottest, then cooled the moment
// something busier appeared, though its own contents never changed. A given
// room now always looks the same colour, which is the only way the colour
// can mean anything as you walk.
//
// The ramp runs cold blue → violet → magenta → crimson → hot orange: five
// clearly distinct steps, every one held to a low lightness on purpose,
// since cells carry pale text and coloured entity names on top and a bright
// fill would swallow both. The bands assume the default score of 1 per
// entity, so they read roughly as one, a pair, a few, a crowd, a mob.
// Score at which each colour in the ramp takes over — one, a pair, a few, a
// crowd, a mob, assuming the default of a point per entity.
const HEAT_MIN = [1, 2, 4, 7, 11];

// Overwritten by whatever Lua sends with each push; these are only what the
// panel draws with before the first frame arrives.
let shading = "gradient";
let colours = ["#16244f", "#3a1a5e", "#661a52", "#8c1f33", "#9c3000"];

function heatColour(score) {
  if (shading === "off" || score <= 0) return "";
  // Flat shading means "something is here, never mind how much" — which is
  // what the bottom band already means, so it borrows that colour rather
  // than needing one of its own.
  if (shading === "flat") return colours[0];
  let step = -1;
  for (let i = 0; i < HEAT_MIN.length; i++) {
    if (score >= HEAT_MIN[i]) step = i;
  }
  if (step < 0) return "";
  // A short colour list just tops out early rather than dropping the
  // highest bands on the floor.
  return colours[Math.min(step, colours.length - 1)];
}

function countColour(n) {
  if (n >= 4) return "#f55";
  if (n === 3) return "#fd5";
  if (n === 2) return "#5ff";
  return "#5f5";
}

// The grid is always drawn, even with nothing in range. An empty five-by-five
// is the honest picture of a quiet street, and it holds its place in the
// layout — swapping in a text placeholder made the panel flicker between two
// completely different shapes every time the last NPC wandered off.
function render(rooms) {
  gridEl.innerHTML = "";
  offgridEl.innerHTML = "";
  terrainWrapEl.hidden = true;

  // Two rooms can share a square — "1 ne" and "1 n, 1 e" describe the same
  // spot — so squares accumulate rather than overwrite.
  const cells = new Map();
  const offgrid = [];
  for (const room of rooms || []) {
    const at = gridOffset(room.direction);
    if (!at) {
      offgrid.push(room);
      continue;
    }
    const key = at.x + "," + at.y;
    let cell = cells.get(key);
    if (!cell) {
      cell = { score: 0, entities: [], count: 0 };
      cells.set(key, cell);
    }
    cell.score += room.score;
    for (const e of room.entities) {
      cell.entities.push(e);
      cell.count += e.count > 1 ? e.count : 1;
    }
  }

  let max = 0;
  for (const cell of cells.values()) max = Math.max(max, cell.score);

  for (let y = -GRID_RADIUS; y <= GRID_RADIUS; y++) {
    for (let x = -GRID_RADIUS; x <= GRID_RADIUS; x++) {
      const el = document.createElement("div");
      el.className = "cell";
      // Chebyshev distance: one step away is the ring you can actually walk
      // to this move, two is everything beyond it.
      el.classList.add(Math.max(Math.abs(x), Math.abs(y)) === 1 ? "ring1" : "ring2");

      if (x === 0 && y === 0) {
        el.classList.add("you");
        el.textContent = "@";
        el.title = "You are here";
        gridEl.appendChild(el);
        continue;
      }

      const cell = cells.get(x + "," + y);
      if (cell) {
        el.classList.add("filled");
        const bg = heatColour(cell.score);
        if (bg) el.style.background = bg;
        // Outline the busiest square in view. This one is deliberately
        // relative — it answers "where should I go next", which is a
        // question about right now, not about the room in isolation.
        if (max > 0 && cell.score === max) el.classList.add("hot");
        el.title = "[" + cell.score + "] " + entityText(cell.entities);

        const badge = document.createElement("div");
        badge.className = "cell-count";
        badge.textContent = String(cell.count);
        badge.style.color = countColour(cell.count);
        el.appendChild(badge);

        const body = document.createElement("div");
        body.className = "cell-entities";
        for (const e of cell.entities) body.appendChild(entitySpan(e));
        el.appendChild(body);
      } else {
        const label = EDGE_LABELS[x + "," + y];
        if (label) {
          el.classList.add("edge");
          el.textContent = label;
        } else {
          el.classList.add("blank");
        }
      }

      gridEl.appendChild(el);
    }
  }

  gridEl.hidden = false;
  if (offgrid.length > 0) {
    appendRoomRows(offgridEl, offgrid);
    offgridEl.hidden = false;
  } else {
    offgridEl.hidden = true;
  }
}

// The terrain map has no compass squares to fill, but a panel that went
// blank the moment you stepped off the map would look broken — so this
// panel shows the same map the Nearby panel does.
function renderTerrain(rows) {
  if (!renderTerrainInto(terrainEl, rows)) {
    // Nothing to draw: fall back to the empty grid rather than a blank
    // panel, for the same reason render() always draws one.
    render([]);
    return;
  }
  gridEl.hidden = true;
  offgridEl.hidden = true;
  terrainWrapEl.hidden = false;
}

window.addEventListener("message", (ev) => {
  const m = ev.data;
  if (!m) return;
  if (m.name === "rooms") {
    const cfg = m.data.radar;
    if (cfg) {
      if (cfg.shading) shading = cfg.shading;
      if (Array.isArray(cfg.colours) && cfg.colours.length > 0) colours = cfg.colours;
    }
    render(m.data.rooms || []);
  } else if (m.name === "terrain") renderTerrain(m.data.rows || []);
});

// Signal readiness so Lua can push the initial snapshot.
window.parent.postMessage({ name: "__ready__" }, "*");
