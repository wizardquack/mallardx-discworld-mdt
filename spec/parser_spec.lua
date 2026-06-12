local parser = require("parser")

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
