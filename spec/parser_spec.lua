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

  it("recognises nautical singles", function()
    assert.is_true(parser.is_direction("fore"))
    assert.is_true(parser.is_direction("aft"))
    assert.is_true(parser.is_direction("port"))
    assert.is_true(parser.is_direction("starboard"))
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

  it("strips embedded ANSI SGR sequences from entity labels", function()
    -- Real Discworld emission captured from the user's manual test:
    -- per-user auto-colouring wraps the player name in SGR escapes ON TOP
    -- of any MXP wrapper. The label that reaches the panel must be just
    -- the bare name with no escape bytes.
    local input = "a watchman and "
      .. "\27[38;5;157mterrible kiki totally\27[39;49m\27[0m"
      .. " are north, the limit of your vision is here."
    local rooms = parser.parse(input)
    assert.equals(1, #rooms)
    assert.equals(2, #rooms[1].entities)
    assert.equals("watchman", rooms[1].entities[1].label)
    assert.is_nil(rooms[1].entities[1].sgr_colour)
    assert.equals("terrible kiki totally", rooms[1].entities[2].label)
    assert.equals("#afffaf", rooms[1].entities[2].sgr_colour)
  end)

  it("recognises basic SGR foreground colours (30-37)", function()
    -- "\27[31m" = red dim → #aa0000
    local input = "\27[31mfoo\27[0m is north, the limit of your vision is here."
    local rooms = parser.parse(input)
    assert.equals("foo", rooms[1].entities[1].label)
    assert.equals("#aa0000", rooms[1].entities[1].sgr_colour)
  end)

  it("recognises bright SGR foreground colours (90-97)", function()
    -- "\27[92m" = bright green → #55ff55
    local input = "\27[92mbar\27[0m is north, the limit of your vision is here."
    local rooms = parser.parse(input)
    assert.equals("bar", rooms[1].entities[1].label)
    assert.equals("#55ff55", rooms[1].entities[1].sgr_colour)
  end)

  it("recognises 24-bit truecolour SGR", function()
    -- "\27[38;2;128;64;200m" = #8040c8
    local input = "\27[38;2;128;64;200mbaz\27[0m is north, the limit of your vision is here."
    local rooms = parser.parse(input)
    assert.equals("baz", rooms[1].entities[1].label)
    assert.equals("#8040c8", rooms[1].entities[1].sgr_colour)
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

  it("parses a nautical compound direction as one short token", function()
    -- "minister coral is one port fore, the limit of your vision is one
    -- port fore from here." — entity at compound direction "pf".
    local input = "alice is one port fore, the limit of your vision is one port fore from here."
    local rooms = parser.parse(input)
    assert.equals(1, #rooms)
    assert.equals("1 pf", rooms[1].direction)
    assert.equals("alice", rooms[1].entities[1].label)
  end)

  it("silently consumes split exit lists (boats: 'exits X and Y of one Z')", function()
    -- " and " → ", " splits multi-direction exit lists into separate
    -- segments. The continuation must stay in ignoring_exits, not leak
    -- out as an entity. Real boat shape:
    --   "exits aft and fore of one starboard, a watchman is one starboard,
    --    the limit of your vision is one starboard from here."
    local input = "exits aft and fore of one starboard, a watchman is one starboard, the limit of your vision is one starboard from here."
    local rooms = parser.parse(input)
    assert.equals(1, #rooms)
    assert.equals("1 sb", rooms[1].direction)
    assert.equals(1, #rooms[1].entities)
    assert.equals("watchman", rooms[1].entities[1].label)
  end)

  it("silently consumes exit-list continuations that start with a direction", function()
    -- "exits starboard fore, port fore, starboard and port of one aft" —
    -- the trailing "port of one aft" begins with a direction but is part
    -- of the exit description, not a room of its own.
    local input = "exits starboard fore, port fore, starboard and port of one aft, a dun horse is one aft and the limit of your vision is one aft from here."
    local rooms = parser.parse(input)
    assert.equals(1, #rooms)
    assert.equals("1 a", rooms[1].direction)
    assert.equals(1, #rooms[1].entities)
    assert.equals("dun horse", rooms[1].entities[1].label)
  end)

  it("treats sentinels with a direction qualifier as flush markers", function()
    -- Boat sentinels are "the limit of your vision is one <dir> from here",
    -- one per visible direction. Each one flushes the current room.
    local input = "alice is one fore, the limit of your vision is one fore from here, bob is one aft and the limit of your vision is one aft from here."
    local rooms = parser.parse(input)
    assert.equals(2, #rooms)
    assert.equals("1 f", rooms[1].direction)
    assert.equals("alice", rooms[1].entities[1].label)
    assert.equals("1 a", rooms[2].direction)
    assert.equals("bob", rooms[2].entities[1].label)
  end)

  it("parses the on-deck boat fixture into 2 rooms with no door leakage", function()
    local rooms = parser.parse(load_fixture("writtenmap_boat_deck.txt"))
    -- Expect: 1 sb → {moon dragon, minister coral, deckhand ravn}; 1 a → {dun horse}.
    -- The "one starboard aft" / "one port aft" / "one port" sentinels at
    -- empty directions must NOT produce rooms. The multi-direction exit
    -- lists must NOT produce entities like "port fore" or "port of one aft".
    assert.equals(2, #rooms)
    assert.equals("1 sb", rooms[1].direction)
    assert.equals(3, #rooms[1].entities)
    assert.equals("lemon cream moon dragon", rooms[1].entities[1].label)
    assert.equals("minister coral", rooms[1].entities[2].label)
    assert.equals("deckhand ravn", rooms[1].entities[3].label)
    assert.equals("1 a", rooms[2].direction)
    assert.equals(1, #rooms[2].entities)
    assert.equals("dun horse", rooms[2].entities[1].label)
  end)

  it("ignores the orphan tail of a multi-direction boat sentinel", function()
    -- "the limit of your vision is one aft and one port aft from here"
    -- becomes "...: one aft, one port aft from here" after " and " → ", ".
    -- The head ("...vision: one aft") flushes via the prefix branch; the
    -- tail ("one port aft from here") used to leak as an entity. It must
    -- be caught and treated as a flush marker too.
    local input = "alice is one fore, the limit of your vision is one aft and one port aft from here."
    local rooms = parser.parse(input)
    -- alice@1 f flushes via direction→entity rule? Actually alice is
    -- followed by the sentinel directly; we only get a room for alice if
    -- the trailing flush picks it up. The sentinel flushes alice@1 f.
    assert.equals(1, #rooms)
    assert.equals("1 f", rooms[1].direction)
    assert.equals("alice", rooms[1].entities[1].label)
    -- Crucially: no phantom "port aft from here" entity in any room.
    for _, room in ipairs(rooms) do
      for _, e in ipairs(room.entities) do
        assert.is_nil(e.label:match("from here"))
      end
    end
  end)

  it("parses the multi-sentinel boat fixture with kiki at one port fore", function()
    local rooms = parser.parse(load_fixture("writtenmap_boat_multi_sentinel.txt"))
    -- Expect: 1 a → {deckhand ravn}; 1 pf → {dun horse, suitcase ..., terrible kiki totally}.
    -- The multi-direction sentinels and split exit lists must NOT produce
    -- phantom "X from here" / "X of one Y" entities, and no extra rooms.
    assert.equals(2, #rooms)
    assert.equals("1 a", rooms[1].direction)
    assert.equals(1, #rooms[1].entities)
    assert.equals("deckhand ravn", rooms[1].entities[1].label)
    assert.equals("1 pf", rooms[2].direction)
    assert.equals(3, #rooms[2].entities)
    assert.equals("dun horse", rooms[2].entities[1].label)
    assert.equals("suitcase the giant fruitbat", rooms[2].entities[2].label)
    assert.equals("terrible kiki totally", rooms[2].entities[3].label)
  end)

  it("parses the belowdecks boat fixture into 2 rooms with compound dir", function()
    local rooms = parser.parse(load_fixture("writtenmap_boat_below.txt"))
    -- Expect: 1 pf → {minister coral}; 2 a → {bitey, nugget}.
    assert.equals(2, #rooms)
    assert.equals("1 pf", rooms[1].direction)
    assert.equals(1, #rooms[1].entities)
    assert.equals("minister coral", rooms[1].entities[1].label)
    assert.equals("2 a", rooms[2].direction)
    assert.equals(2, #rooms[2].entities)
    assert.equals("bitey the sky blue swamp dragon", rooms[2].entities[1].label)
    assert.equals("nugget the dark purple swamp dragon", rooms[2].entities[2].label)
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
