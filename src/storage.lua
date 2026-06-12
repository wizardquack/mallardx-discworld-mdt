-- Per-character storage of the MDT match list.
--
-- Key shape: "matches:<char-name>" — uses char.info.name (NOT capname).
-- Before the character name is known we read/write the "_default" bucket
-- so users can add patterns before logging in / on a freshly-installed
-- plugin.
--
-- The character name is resolved from the GMCP mirror on every call
-- rather than cached in a module upvalue. Mallard's custom `require()`
-- (sandbox.rs:78-99) does NOT use `package.loaded` to cache module
-- results, so each `require("storage")` returns a fresh module table
-- with its own copy of module-private state. Reading from the GMCP
-- mirror at call time gives a single source of truth that both
-- main.lua's and commands.lua's instances see consistently.
--
-- The match list is an ordered array; see src/matcher.lua for the record
-- shape.

local M = {}

local function key()
  local name = gmcp.get("char.info.name")
  if name == nil or name == "" then return "matches:_default" end
  return "matches:" .. name
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
