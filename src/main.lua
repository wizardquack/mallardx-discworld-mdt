-- Discworld MDT — entry point.
--
-- Wires three things together:
--   1. The "Nearby" and "Radar" panels, fed by GMCP room.writtenmap
--      pushes — same data, two layouts.
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

-- Two panels over one data stream: "Nearby" renders the scored rows,
-- "Radar" renders the same rooms as a 5x5 grid. Every push goes to both,
-- so a user can dock either or both and each is correct as soon as it is
-- opened. A panel that isn't in the layout simply has nowhere to draw.
local panel = mud.panel("mdt")
local grid_panel = mud.panel("grid")
local gate = panelgate.new()

local function post_both(name, data)
  panel:post(name, data)
  grid_panel:post(name, data)
end

-- ─── Radar appearance ───────────────────────────────────────────────────

local RADAR_BANDS = 5

-- One entry per band: the user's colour where they have set a valid one, and
-- an empty string where they haven't. Empty leaves the band to the panel's
-- own themed default, which is what makes the Radar follow light and dark
-- themes out of the box. Anything unparseable is treated as unset, so a typo
-- costs that band its custom colour rather than the panel.
local function radar_colours()
  local out = {}
  for i = 1, RADAR_BANDS do
    local value = settings.get("radar_colour_" .. i)
    out[i] = ""
    if type(value) == "string" then
      value = value:match("^%s*(.-)%s*$")
      -- Accept a bare "16244f" too; the hash is easy to leave off.
      if value:match("^%x%x%x$") or value:match("^%x%x%x%x%x%x$") then
        value = "#" .. value
      end
      if value:match("^#%x%x%x$") or value:match("^#%x%x%x%x%x%x$") then
        out[i] = value
      end
    end
  end
  return out
end

-- Only the Radar panel reads this; the Nearby panel ignores it. Sent with
-- every push so a panel opened later is styled correctly on its first frame.
--
-- Cached, because it is otherwise rebuilt on every room move — six settings
-- reads plus a fresh table and the hex-parsing in radar_colours() — purely to
-- attach a value that only changes on a settings change. The cache is dropped
-- there (see settings.on("change") below), so the movement hot path just
-- returns the built table.
local radar_config_cache = nil

local function radar_config()
  if radar_config_cache then return radar_config_cache end
  local shading = settings.get("radar_shading")
  if shading ~= "flat" and shading ~= "off" then shading = "gradient" end
  radar_config_cache = {
    shading = shading,
    colours = radar_colours(),
    grouped = settings.get("radar_group_names") == true,
  }
  return radar_config_cache
end

-- Flatten the pipeline's scored output to the panel's shape and push it.
-- Both the GMCP room.writtenmap path and the inline map-door-text trigger
-- call this. The gate suppresses a post whose room set matches the last one
-- shipped, so when both pipelines fire for the same move the panel is still
-- driven only once (see panelgate.lua). A terrain frame resets the gate (in
-- the GMCP handler below) so the next room set always re-posts and switches
-- the panel back out of map mode.
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
  post_both("rooms", { rooms = rooms, radar = radar_config() })
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
-- The Radar's appearance settings don't change the scored rooms at all, so
-- the panel gate would see an identical signature and swallow the push. Clear
-- the baseline first: a settings change is exactly when a re-post is wanted.
settings.on("change", function()
  radar_config_cache = nil
  panelgate.reset(gate)
  refresh()
end)

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
    post_both("terrain", { rows = parser.parse_terrain(payload) })
    -- The panel is now in map mode, so the next entity frame MUST re-post to
    -- switch it back to nearby-text mode — even when that frame is identical
    -- to the last one seen before going overboard (climbing back aboard the
    -- same deck spot). Both dedup gates would otherwise suppress it and leave
    -- the panel stuck rendering the map: the raw last_payload check below, and
    -- the scored-output panelgate in push_panel. Clear both here.
    last_payload = nil
    panelgate.reset(gate)
    return
  end
  -- Unchanged room re-send: nothing to do, and skipping keeps this callback
  -- under the host's fast-path threshold.
  if payload == last_payload then return end
  render_payload(payload)
end)

-- ─── Commands + inline trigger ──────────────────────────────────────────

inline.register(push_panel)

-- ─── Initial paint ──────────────────────────────────────────────────────

-- Without this the panels stay blank from a plugin reload (or a mid-session
-- enable) until the next room change, which reads as "it isn't working" when
-- you are standing still. Mallard mirrors the last GMCP frame per package, so
-- the current room's writtenmap is already there for the asking.
--
-- Wrapped: gmcp.get is permission-checked against the full key it is given
-- and a refusal raises rather than returning nil, which would take the whole
-- entry file down over a convenience. Nothing here is load-bearing — without
-- it the panels simply fill on the next move, as they did before.
local ok, seed = pcall(gmcp.get, "room.writtenmap")
if ok and type(seed) == "string" and seed ~= "" then
  if parser.is_terrain(seed) then
    post_both("terrain", { rows = parser.parse_terrain(seed) })
  else
    render_payload(seed)
  end
end

commands.register(refresh)
