-- Integration spec for the GMCP room.writtenmap routing in main.lua.
--
-- The "Nearby" panel switches render mode purely on which post arrives:
-- a "rooms" post puts panel.js into nearby-text mode, a "terrain" post
-- into map mode (ui/panel.js). So leaving map mode REQUIRES a "rooms"
-- post to be sent.
--
-- These tests stub the host globals (mud / gmcp / settings / world /
-- storage), require the real main.lua so its real gmcp handler + pipeline
-- run, capture every panel:post, and drive the handler with raw payloads.

local function load_fixture(name)
  local f = assert(io.open("spec/fixtures/" .. name, "r"))
  local s = f:read("*a")
  f:close()
  s = s:gsub("ESC", "\27")
  s = s:gsub("\n$", "")
  return s
end

-- Fresh host stubs + a fresh load of main.lua per call. Returns a handle
-- exposing the captured posts and a `fire(payload)` that invokes the real
-- room.writtenmap GMCP handler main.lua registered.
local function load_main()
  local posts = {}
  local panel = {
    post = function(_self, name, data) posts[#posts + 1] = { name = name, data = data } end,
  }
  local handlers = {}

  _G.mud = {
    panel = function(_) return panel end,
    note = function() end,
    span = function(s) return s end,
    command = function() end,
  }
  _G.gmcp = {
    on = function(pkg, fn) handlers[pkg] = fn end,
    get = function() return nil end,
  }
  _G.settings = {
    on = function() end,
    get = function(name)
      local d = { default_score = 1, min_score = 0, max_rooms = 20 }
      return d[name]
    end,
  }
  _G.world = { on = function() end }
  _G.storage = { get = function() return {} end, set = function() end }

  -- Mallard's require() doesn't use package.loaded; busted's does, so clear
  -- main so each test re-runs its registration with the fresh stubs above.
  package.loaded["main"] = nil
  require("main")

  return {
    posts = posts,
    fire = function(payload) handlers["room.writtenmap"](nil, payload) end,
    last_post = function() return posts[#posts] end,
  }
end

describe("main.lua room.writtenmap routing", function()
  local entity, terrain
  setup(function()
    entity = load_fixture("writtenmap_basic.txt")    -- single-line, has vision sentinel
    terrain = load_fixture("writtenmap_terrain.txt")  -- multi-line ASCII map, no sentinel
  end)

  it("classifies the two fixtures the way the test assumes", function()
    local parser = require("parser")
    assert.is_false(parser.is_terrain(entity))
    assert.is_true(parser.is_terrain(terrain))
  end)

  it("posts rooms for an entity frame and terrain for a terrain frame", function()
    local h = load_main()
    h.fire(entity)
    assert.equals("rooms", h.last_post().name)
    h.fire(terrain)
    assert.equals("terrain", h.last_post().name)
  end)

  -- The regression: jump overboard (terrain) then climb back aboard the
  -- SAME deck spot, so the on-board frame is byte-identical to the last
  -- entity frame seen before the jump. The raw last_payload dirty-check
  -- must not suppress this frame, or the panel stays stuck in map mode.
  it("re-posts rooms when returning to the same room after terrain", function()
    local h = load_main()
    h.fire(entity)   -- on board → rooms
    h.fire(terrain)  -- overboard → terrain (panel now in map mode)
    h.fire(entity)   -- back aboard, SAME room → must re-post rooms
    assert.equals("rooms", h.last_post().name)
  end)

  -- The perf dirty-check is still wanted: an identical entity frame with no
  -- intervening terrain (Discworld re-sends on `look` / pacing) is skipped.
  it("still suppresses a repeated entity frame with no terrain between", function()
    local h = load_main()
    h.fire(entity)
    local n = #h.posts
    h.fire(entity)
    assert.equals(n, #h.posts)
  end)
end)
