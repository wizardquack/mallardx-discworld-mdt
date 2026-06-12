-- Shared scoring pipeline. Both the panel push (main.lua) and the inline
-- map-door-text trigger (inline.lua) feed off this. Takes a raw
-- writtenmap payload (string with embedded MXP/SGR), returns a
-- scored / filtered / sorted / capped list of room records.

local parser  = require("parser")
local matcher = require("matcher")
local storage = require("storage")

local M = {}

local function setting(name, default)
  local v = settings.get(name)
  if v == nil then return default end
  return v
end

-- Returns an array of room records, each:
--   { direction = string, total_score = number,
--     entities = [{label, count, score, colour}, ...] }
function M.score_payload(payload)
  local rooms = parser.parse(payload)
  local match_list = storage.load()
  local default_score = setting("default_score", 1)
  local min_score = setting("min_score", 0)
  local max_rooms = setting("max_rooms", 20)

  local scored = {}
  for _, room in ipairs(rooms) do
    local s = matcher.score_room(room, match_list, default_score)
    if s.total_score >= min_score then
      scored[#scored + 1] = s
    end
  end
  table.sort(scored, function(a, b) return a.total_score > b.total_score end)
  while #scored > max_rooms do table.remove(scored) end
  return scored
end

return M
