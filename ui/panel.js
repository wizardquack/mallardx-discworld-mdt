const roomsEl = document.getElementById("rooms");
const emptyEl = document.getElementById("empty");

function colourClass(colour) {
  if (!colour) return "";
  if (colour.startsWith("#")) return "";  // hex handled inline
  return "c-" + colour;
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
    dir.textContent = room.direction;
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
