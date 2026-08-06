// Rendering helpers shared by the two MDT panels: "Nearby" (scored rows,
// panel.js) and "Radar" (5x5 grid, grid.js). Both receive the same
// "rooms" and "terrain" messages from Lua and differ only in how they lay
// the rooms out, so entity styling, direction formatting and the terrain
// map live here rather than drifting apart in two copies.

function colourClass(colour) {
  if (!colour) return "";
  if (colour.startsWith("#")) return "";  // hex handled inline
  return "c-" + colour;
}

// Tighten "1 nw, 2 w" → "nw, 2w" — elide the "1" entirely, drop the space
// when count > 1. Keeps the panel's first column compact at narrow widths.
function formatDirection(s) {
  return s.split(", ").map((tok) => {
    const m = tok.match(/^(\d+) (\S+)$/);
    if (!m) return tok;
    const [, n, d] = m;
    return n === "1" ? d : n + d;
  }).join(", ");
}

function entitySpan(e) {
  const span = document.createElement("span");
  span.className = "entity " + colourClass(e.colour);
  if (e.colour && e.colour.startsWith("#")) {
    span.style.color = e.colour;
  }
  if (e.count > 1) {
    const c = document.createElement("span");
    c.className = "count";
    c.textContent = e.count + " ";
    span.appendChild(c);
  }
  span.appendChild(document.createTextNode(e.label));
  return span;
}

// Plain-text form of a room's entities, for the grid's cell tooltips.
function entityText(entities) {
  return entities
    .map((e) => (e.count > 1 ? e.count + " " : "") + e.label)
    .join(", ");
}

// The direction / score / entities rows. Used for the whole of the Nearby
// panel, and for the grid panel's off-grid strip.
function appendRoomRows(container, rooms) {
  for (const room of rooms) {
    const dir = document.createElement("div");
    dir.className = "dir";
    dir.textContent = formatDirection(room.direction);
    container.appendChild(dir);

    const score = document.createElement("div");
    score.className = "score";
    score.textContent = "[" + room.score + "]";
    container.appendChild(score);

    const entities = document.createElement("div");
    entities.className = "entities";
    for (const e of room.entities) entities.appendChild(entitySpan(e));
    container.appendChild(entities);
  }
}

// Paint the ASCII terrain map into `el`. Returns false when there is
// nothing to draw, so the caller can fall back to its empty state.
function renderTerrainInto(el, rows) {
  el.innerHTML = "";
  if (!rows || rows.length === 0) return false;
  for (let r = 0; r < rows.length; r++) {
    for (const cell of rows[r]) {
      if (cell.fg) {
        const span = document.createElement("span");
        span.style.color = cell.fg;
        if (cell.bold) span.style.fontWeight = "bold";
        span.textContent = cell.char;
        el.appendChild(span);
      } else {
        el.appendChild(document.createTextNode(cell.char));
      }
    }
    if (r < rows.length - 1) el.appendChild(document.createTextNode("\n"));
  }
  return true;
}
