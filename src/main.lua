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

local pipeline  = require("pipeline")
local parser    = require("parser")
local commands  = require("commands")
local inline    = require("inline")
local panelgate = require("panelgate")

local panel = mud.panel("mdt")
local gate = panelgate.new()

-- Flatten the pipeline's scored output to the panel's shape and push it.
-- Both the GMCP room.writtenmap path and the inline map-door-text trigger
-- call this. The gate suppresses a post whose room set matches the last one
-- shipped, so when both pipelines fire for the same move the panel is still
-- driven only once (see panelgate.lua).
local function push_panel(scored)
  local rooms = {}
  for _, s in ipairs(scored) do
    rooms[#rooms + 1] = {
      direction = s.direction,
      score = s.total_score,
      entities = s.entities,
    }
  end
  if not panelgate.should_post(gate, rooms) then return end
  panel:post("rooms", { rooms = rooms })
end

-- ─── GMCP wiring ─────────────────────────────────────────────────────────

-- Last entity-variant writtenmap payload we scored. Discworld re-sends the
-- same frame on `look` and on pacing back and forth in one room; comparing
-- the raw payload lets us skip the whole parse → storage.load → score → post
-- pipeline (a blocking SQLite read among it) for an unchanged room.
local last_payload = nil

local function render_payload(payload)
  last_payload = payload
  push_panel(pipeline.score_payload(payload))
end

-- A match-list edit (mdt add/remove/clear) or a settings change re-scores
-- the *same* room differently, so the dirty-check above would wrongly
-- suppress it. Re-run the pipeline against the last payload directly; the
-- panel gate still collapses it to a single post if the output is unchanged.
-- Standing in a room with no new frame, this is what refreshes the panel.
local function refresh()
  if last_payload then
    push_panel(pipeline.score_payload(last_payload))
  end
end

-- All three settings (default_score, min_score, max_rooms) are read inline
-- at the top of pipeline.score_payload(), so a re-score picks up new values
-- with no restart. (Registering a handler also opts out of the host's
-- restart-on-change default.)
settings.on("change", refresh)

gmcp.on("room.writtenmap", function(_pkg, payload)
  if type(payload) ~= "string" then
    mud.note("[mdt] unexpected room.writtenmap payload shape", { fg = "yellow" })
    return
  end
  -- Discworld sends a terrain ASCII-art map via the same frame when the
  -- player is outside any city — completely different shape from the
  -- entity-list variant. Route it to its own panel view instead of
  -- feeding the entity parser garbage.
  if parser.is_terrain(payload) then
    panel:post("terrain", { rows = parser.parse_terrain(payload) })
    return
  end
  -- Unchanged room re-send: nothing to do, and skipping keeps this callback
  -- under the host's fast-path threshold.
  if payload == last_payload then return end
  render_payload(payload)
end)

-- ─── Commands + inline trigger ──────────────────────────────────────────

inline.register(push_panel)

commands.register(refresh)
