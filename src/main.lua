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

-- Flatten the pipeline's scored output to the panel's shape and push it.
-- Both the GMCP room.writtenmap path and the inline map-door-text trigger
-- call this so the panel stays in sync with whichever payload arrived
-- most recently.
local function push_panel(scored)
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
  push_panel(pipeline.score_payload(payload))
end)

-- ─── Commands + inline trigger ──────────────────────────────────────────

inline.register(push_panel)

commands.register()
