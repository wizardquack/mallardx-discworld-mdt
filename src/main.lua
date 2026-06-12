-- Discworld MDT — entry point.
--
-- Wires three things together:
--   1. The "Nearby" panel, fed by GMCP room.writtenmap pushes.
--   2. The mdt slash commands (mdt add / remove / list / clear).
--   3. The inline map-door-text trigger, which gags the textual sentinel
--      line and re-emits a styled version in the game-output pane.
--
-- The shared parse→score→filter→sort→cap pipeline lives in
-- src/pipeline.lua so both the panel push and the inline trigger use one
-- implementation.

local pipeline = require("pipeline")
local commands = require("commands")
local inline   = require("inline")

local panel = mud.panel("mdt")

local function refresh(payload)
  local scored = pipeline.score_payload(payload)
  -- Flatten to the panel's shape: { direction, score, entities }.
  local rooms = {}
  for _, s in ipairs(scored) do
    rooms[#rooms + 1] = {
      direction = s.direction,
      score = s.total_score,
      entities = s.entities,
    }
  end
  panel:post("rooms", { rooms = rooms })
end

-- ─── GMCP wiring ─────────────────────────────────────────────────────────

gmcp.on("room.writtenmap", function(_pkg, payload)
  if type(payload) ~= "string" then
    mud.note("[mdt] unexpected room.writtenmap payload shape", { fg = "yellow" })
    return
  end
  refresh(payload)
end)

-- ─── Commands + inline trigger ──────────────────────────────────────────

inline.register()

commands.register(function()
  if panel.open then panel:open() end
end)
