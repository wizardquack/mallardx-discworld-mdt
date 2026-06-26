-- De-dup gate for the "Nearby" panel.
--
-- Two pipelines feed the panel with the same data per room move: the GMCP
-- room.writtenmap push (main.lua) and the inline map-door-text trigger
-- (inline.lua). Before this gate they each called panel:post, so the panel
-- was serialised and shipped across the iframe bridge twice per move. The
-- gate computes a stable signature of the scored-room list and suppresses a
-- post whose signature matches the last one shipped, so whichever pipeline
-- arrives second is a no-op and the panel is driven once.
--
-- A match-list edit or settings change re-scores the same room into a
-- different list, which yields a different signature — so genuine changes
-- still post.

local M = {}

-- Field/record separators are control bytes that can't appear in entity
-- labels or directions, so no value can straddle a boundary and collide
-- with a different split (see the boundary case in panelgate_spec).
local FIELD = "\1"
local ENTITY = "\3"
local ROOM = "\4"

-- Stable string signature of a scored-room list (panel "rooms" shape:
-- { direction, score, entities = { { label, count, colour }, ... } }).
function M.signature(rooms)
  local parts = {}
  for _, r in ipairs(rooms) do
    local ents = {}
    for _, e in ipairs(r.entities or {}) do
      ents[#ents + 1] = (e.label or "") .. FIELD ..
        tostring(e.count or "") .. FIELD .. (e.colour or "")
    end
    parts[#parts + 1] = (r.direction or "") .. FIELD ..
      tostring(r.score or "") .. FIELD .. table.concat(ents, ENTITY)
  end
  return table.concat(parts, ROOM)
end

function M.new()
  return { last = nil }
end

-- Returns true and records the signature when `rooms` differs from the last
-- posted set; returns false (caller should skip panel:post) when unchanged.
function M.should_post(state, rooms)
  local sig = M.signature(rooms)
  if sig == state.last then return false end
  state.last = sig
  return true
end

return M
