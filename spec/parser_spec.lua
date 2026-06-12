local parser = require("parser")

local function load_fixture(name)
  local f = assert(io.open("spec/fixtures/" .. name, "r"))
  local s = f:read("*a")
  f:close()
  -- Substitute "ESC" placeholder for the real \27 byte so the fixture file
  -- stays human-editable.
  s = s:gsub("ESC", "\27")
  -- Strip a single trailing newline (text editors add one).
  s = s:gsub("\n$", "")
  return s
end

describe("parser.normalise", function()
  it("lowercases input", function()
    assert.equals("a wizard", parser.normalise("A Wizard"))
  end)

  it("collapses ' and ' to ', '", function()
    assert.equals("a, b", parser.normalise("a and b"))
  end)

  it("collapses ' is ' and ' are ' to ', '", function()
    assert.equals("a, b", parser.normalise("a is b"))
    assert.equals("a, b", parser.normalise("a are b"))
  end)

  it("rewrites the vision sentinel", function()
    assert.equals("foo the limit of your vision: bar",
      parser.normalise("foo the limit of your vision is bar"))
  end)

  -- Note: normalise does NOT strip MXP wrappers — parser.parse handles
  -- MXP separately so colours can be preserved as entity metadata. See
  -- mxp_spec.lua for wrapper stripping.
end)

describe("parser.parse_count", function()
  it("returns (1, s) when no count prefix", function()
    local n, rest = parser.parse_count("watchman")
    assert.equals(1, n)
    assert.equals("watchman", rest)
  end)

  it("strips a numeric prefix", function()
    local n, rest = parser.parse_count("3 watchmen")
    assert.equals(3, n)
    assert.equals("watchmen", rest)
  end)

  it("strips a number-word prefix", function()
    local n, rest = parser.parse_count("two watchmen")
    assert.equals(2, n)
    assert.equals("watchmen", rest)
  end)

  it("strips a leading article after the count", function()
    -- Real example: "the watchman" with no count → (1, "watchman")
    local n, rest = parser.parse_count("the watchman")
    assert.equals(1, n)
    assert.equals("watchman", rest)
  end)
end)

describe("parser.is_direction", function()
  it("recognises short forms", function()
    assert.is_true(parser.is_direction("n"))
    assert.is_true(parser.is_direction("ne"))
    assert.is_true(parser.is_direction("sw"))
    assert.is_true(parser.is_direction("u"))
    assert.is_true(parser.is_direction("d"))
  end)

  it("recognises long forms", function()
    assert.is_true(parser.is_direction("north"))
    assert.is_true(parser.is_direction("northeast"))
    assert.is_true(parser.is_direction("up"))
    assert.is_true(parser.is_direction("down"))
  end)

  it("rejects non-directions", function()
    assert.is_false(parser.is_direction("watchman"))
    assert.is_false(parser.is_direction(""))
  end)
end)

describe("parser.parse", function()
  it("returns empty list on empty input", function()
    assert.same({}, parser.parse(""))
  end)

  it("parses a single direction with one entity", function()
    local rooms = parser.parse(load_fixture("writtenmap_basic.txt"))
    -- Expected: 2 rooms — { N: 1 watchman }, { NE: 2 cats, 1 dog }
    assert.equals(2, #rooms)
    assert.equals("1 n", rooms[1].direction)
    assert.equals(1, #rooms[1].entities)
    assert.equals("watchman", rooms[1].entities[1].label)
    assert.equals(1, rooms[1].entities[1].count)
    assert.equals("1 ne", rooms[2].direction)
    assert.equals(2, #rooms[2].entities)
  end)

  it("preserves MXP colours on entities", function()
    local rooms = parser.parse(load_fixture("writtenmap_mxp.txt"))
    assert.equals(1, #rooms)
    assert.equals(2, #rooms[1].entities)
    -- First entity: plain "watchman", no MXP colour
    assert.equals("watchman", rooms[1].entities[1].label)
    assert.is_nil(rooms[1].entities[1].mxp_colour)
    -- Second entity: "george" with hex colour
    assert.equals("george", rooms[1].entities[2].label)
    assert.equals("#ff0000", rooms[1].entities[2].mxp_colour)
  end)

  it("ignores door / exit prefix segments", function()
    local rooms = parser.parse(load_fixture("writtenmap_doors.txt"))
    -- Only the watchman room should appear; the "a door is north" segment
    -- is the door-prefix marker and contributes no entities.
    assert.equals(1, #rooms)
    assert.equals("1 e", rooms[1].direction)
    assert.equals("watchman", rooms[1].entities[1].label)
  end)

  it("ignores 'exit <direction> of <count> <direction>' descriptions", function()
    -- Real Discworld emission shape captured from user's manual test:
    -- "an exit south of one west, a spineless lawyer, a watchman and a depressed accountant are west, ..."
    -- The "an exit south of one west" segment must be recognised as a door
    -- token, not treated as an entity.
    local input = "an exit south of one west, a spineless lawyer, a watchman and a depressed accountant are west, the limit of your vision is here."
    local rooms = parser.parse(input)
    assert.equals(1, #rooms)
    assert.equals("1 w", rooms[1].direction)
    assert.equals(3, #rooms[1].entities)
    assert.equals("spineless lawyer", rooms[1].entities[1].label)
    assert.equals("watchman", rooms[1].entities[2].label)
    assert.equals("depressed accountant", rooms[1].entities[3].label)
  end)

  it("handles doubled MXP wrappers (player + title), keeping outer colour", function()
    -- Synthetic input mirroring Discworld's player-with-title MXP shape:
    --   outer wrapper carries the player's class/guild colour;
    --   inner wrapper carries the rank/title colour.
    -- Outer colour should win; the resulting label is just NAME (no markup).
    local input = "a watchman and "
      .. "\27[4zmxp<c #00ff00mxp>"  -- outer open: green
      .. "\27[4zmxp<c #ffffffmxp>"  -- inner open: white
      .. "captain"                     -- name
      .. "\27[3z\27[3z"                -- inner close, outer close
      .. " are north, the limit of your vision is here."
    local rooms = parser.parse(input)
    assert.equals(1, #rooms)
    assert.equals(2, #rooms[1].entities)
    assert.equals("captain", rooms[1].entities[2].label)
    assert.equals("#00ff00", rooms[1].entities[2].mxp_colour)
  end)

  it("flushes on the vision sentinel", function()
    -- Two rooms separated by the sentinel.
    local input = "a cat is north, the limit of your vision is here. a dog is south, the limit of your vision is here."
    local rooms = parser.parse(input)
    assert.equals(2, #rooms)
    assert.equals("1 n", rooms[1].direction)
    assert.equals("1 s", rooms[2].direction)
  end)
end)
