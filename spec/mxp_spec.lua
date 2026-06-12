local mxp = require("mxp")

describe("mxp.unwrap_one", function()
  it("returns plain string unchanged with no colour", function()
    local name, colour = mxp.unwrap_one("watchman")
    assert.equals("watchman", name)
    assert.is_nil(colour)
  end)

  it("strips hex-colour wrapper", function()
    local input = "\27[4zmxp<c #ff0000mxp>george\27[3z"
    local name, colour = mxp.unwrap_one(input)
    assert.equals("george", name)
    assert.equals("#ff0000", colour)
  end)

  it("strips named-colour wrapper", function()
    local input = "\27[4zmxp<magentamxp>frank\27[3z"
    local name, colour = mxp.unwrap_one(input)
    assert.equals("frank", name)
    assert.equals("magenta", colour)
  end)

  it("strips doubled wrapper, keeps outer colour", function()
    -- Player + title gets two adjacent wrappers; outer = name colour
    local input = "\27[4zmxp<c #00ff00mxp>\27[4zmxp<c #ffffffmxp>captain\27[3z\27[3z"
    local name, colour = mxp.unwrap_one(input)
    assert.equals("captain", name)
    assert.equals("#00ff00", colour)
  end)
end)
