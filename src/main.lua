-- Discworld MDT — entry point.
--
-- Subscribes to room.writtenmap (GMCP) and char.info (for the per-character
-- storage key). Each writtenmap frame: decode JSON string → parser →
-- matcher → filter → panel:post("rooms", …).

local parser   = require("parser")
local matcher  = require("matcher")
local storage  = require("storage")
local commands = require("commands")

local panel = mud.panel("mdt")

-- Settings accessor — falls back to defaults if Mallard hasn't loaded
-- settings yet (e.g. during early init).
local function setting(name, default)
  local raw = mud.settings and mud.settings[name]
  if raw == nil then return default end
  return raw
end

local function refresh(payload)
  local rooms = parser.parse(payload)
  local match_list = storage.load()
  local default_score = setting("default_score", 1)
  local min_score = setting("min_score", 0)
  local max_rooms = setting("max_rooms", 20)

  local scored = {}
  for _, room in ipairs(rooms) do
    local s = matcher.score_room(room, match_list, default_score)
    if s.total_score >= min_score then
      scored[#scored + 1] = {
        direction = s.direction,
        score = s.total_score,
        entities = s.entities,
      }
    end
  end
  table.sort(scored, function(a, b) return a.score > b.score end)
  while #scored > max_rooms do table.remove(scored) end

  panel:post("rooms", { rooms = scored })
end

-- ─── GMCP wiring ─────────────────────────────────────────────────────────

-- Mallard's gmcp.on hands callbacks already-decoded Lua values
-- (cf. discworld-vitals/src/main.lua:151). For room.writtenmap the
-- payload is a JSON string → decoded to a Lua string. For char.info
-- the payload is an object → decoded to a Lua table.
gmcp.on("room.writtenmap", function(_pkg, payload)
  if type(payload) ~= "string" then
    mud.note("[mdt] unexpected room.writtenmap payload shape", { colour = "yellow" })
    return
  end
  refresh(payload)
end)

gmcp.on("char.info", function(_pkg, info)
  if type(info) ~= "table" then return end
  if info.name then storage.set_character(info.name) end
end)

-- If char.info has already been mirrored before our subscription, seed from it.
do
  local existing = gmcp.get("char.info.name")
  if existing and existing ~= "" then storage.set_character(existing) end
end

-- ─── Commands ────────────────────────────────────────────────────────────

commands.register(function()
  -- `mdt` with no args → focus/open panel. The panel API uses :open()
  -- on the handle if available; otherwise this is a no-op.
  if panel.open then panel:open() end
end)
