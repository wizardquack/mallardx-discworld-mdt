const roomsEl = document.getElementById("rooms");
const emptyEl = document.getElementById("empty");

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

function render(rooms) {
  roomsEl.innerHTML = "";
  if (!rooms || rooms.length === 0) {
    emptyEl.hidden = false;
    return;
  }
  emptyEl.hidden = true;
  for (const room of rooms) {
    const dir = document.createElement("div");
    dir.className = "dir";
    dir.textContent = formatDirection(room.direction);
    roomsEl.appendChild(dir);

    const score = document.createElement("div");
    score.className = "score";
    score.textContent = "[" + room.score + "]";
    roomsEl.appendChild(score);

    const entities = document.createElement("div");
    entities.className = "entities";
    for (const e of room.entities) {
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
      entities.appendChild(span);
    }
    roomsEl.appendChild(entities);
  }
}

window.addEventListener("message", (ev) => {
  const m = ev.data;
  if (!m || m.name !== "rooms") return;
  render(m.data.rooms || []);
});

// Signal readiness so Lua can push the initial snapshot.
window.parent.postMessage({ name: "__ready__" }, "*");
