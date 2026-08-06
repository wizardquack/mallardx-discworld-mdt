const roomsEl = document.getElementById("rooms");
const emptyEl = document.getElementById("empty");
const terrainWrapEl = document.getElementById("terrain-wrap");
const terrainEl = document.getElementById("terrain");

// Styling, direction formatting and the terrain map are shared with the
// Radar panel; see ui/common.js.

function render(rooms) {
  roomsEl.innerHTML = "";
  terrainWrapEl.hidden = true;
  if (!rooms || rooms.length === 0) {
    emptyEl.hidden = false;
    return;
  }
  emptyEl.hidden = true;
  appendRoomRows(roomsEl, rooms);
}

function renderTerrain(rows) {
  roomsEl.innerHTML = "";
  emptyEl.hidden = true;
  if (!renderTerrainInto(terrainEl, rows)) {
    terrainWrapEl.hidden = true;
    emptyEl.hidden = false;
    return;
  }
  terrainWrapEl.hidden = false;
}

window.addEventListener("message", (ev) => {
  const m = ev.data;
  if (!m) return;
  if (m.name === "rooms") render(m.data.rooms || []);
  else if (m.name === "terrain") renderTerrain(m.data.rows || []);
});

// Signal readiness so Lua can push the initial snapshot.
window.parent.postMessage({ name: "__ready__" }, "*");
