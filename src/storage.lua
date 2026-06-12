-- Per-character storage of the MDT match list.
--
-- Key shape: "matches:<char-name>" — uses char.info.name (NOT capname).
-- Before the character name is known we read/write the "_default" bucket
-- so users can add patterns before logging in / on a freshly-installed
-- plugin.
--
-- The match list is an ordered array; see src/matcher.lua for the record
-- shape.

local M = {}

local current_char = nil

function M.set_character(name)
  -- nil or empty → fall back to default bucket
  if name == nil or name == "" then
    current_char = nil
  else
    current_char = name
  end
end

local function key()
  return "matches:" .. (current_char or "_default")
end

-- Mallard's storage API accepts Lua values natively (serialised on the
-- Rust side via lua_to_json); see src-tauri/src/plugins/lua_api/storage.rs.
-- No need to json.encode here.
function M.load()
  local list = storage.get(key())
  if type(list) ~= "table" then return {} end
  return list
end

local function save(list)
  storage.set(key(), list)
end

function M.add(entry)
  local list = M.load()
  -- Insertion order matters (first-match-wins); append.
  list[#list + 1] = entry
  save(list)
  return list
end

function M.remove_at(index)
  local list = M.load()
  if index < 1 or index > #list then return list, false end
  table.remove(list, index)
  save(list)
  return list, true
end

function M.remove_by_pattern(pattern)
  local list = M.load()
  for i, entry in ipairs(list) do
    if entry.pattern == pattern then
      table.remove(list, i)
      save(list)
      return list, true
    end
  end
  return list, false
end

function M.clear()
  save({})
end

return M
