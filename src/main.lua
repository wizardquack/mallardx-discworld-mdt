-- Discworld MDT — entry point.
--
-- Subscribes to room.writtenmap (GMCP). Each writtenmap frame: parser →
-- matcher → filter → panel:post("rooms", …). The per-character storage
-- key is resolved from gmcp.get("char.info.name") at every storage call
-- (see src/storage.lua for why caching doesn't work here).

local parser   = require("parser")
local matcher  = require("matcher")
local storage  = require("storage")
local commands = require("commands")

local panel = mud.panel("mdt")

-- Settings accessor — falls back to defaults if Mallard hasn't loaded
-- settings yet (e.g. during early init).
local function setting(name, default)
  local v = settings.get(name)
  if v == nil then return default end
  return v
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
-- payload is a JSON string → decoded to a Lua string.
gmcp.on("room.writtenmap", function(_pkg, payload)
  if type(payload) ~= "string" then
    mud.note("[mdt] unexpected room.writtenmap payload shape", { fg = "yellow" })
    return
  end
  refresh(payload)
end)

-- ─── Commands ────────────────────────────────────────────────────────────

commands.register(function()
  -- `mdt` with no args → focus/open panel. The panel API uses :open()
  -- on the handle if available; otherwise this is a no-op.
  if panel.open then panel:open() end
end)
