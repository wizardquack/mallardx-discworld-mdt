local matcher = require("matcher")

describe("matcher.score_entity", function()
  it("returns default score for an unmatched entity", function()
    local result = matcher.score_entity(
      { label = "civilian", count = 1, mxp_colour = nil },
      {},  -- empty match list
      1    -- default score
    )
    assert.equals(1, result.score)
    assert.is_nil(result.colour)
    assert.equals("civilian", result.label)
    assert.equals(1, result.count)
  end)

  it("matches substring (case-insensitive)", function()
    local result = matcher.score_entity(
      { label = "the city watchman", count = 1, mxp_colour = nil },
      { { pattern = "watchman", score = 3, colour = "red", is_regex = false } },
      1
    )
    assert.equals(3, result.score)
    assert.equals("red", result.colour)
  end)

  it("matches Lua regex when is_regex=true", function()
    local result = matcher.score_entity(
      { label = "sgt detritus", count = 1, mxp_colour = nil },
      { { pattern = "^sgt %a+", score = 5, colour = "yellow", is_regex = true } },
      1
    )
    assert.equals(5, result.score)
    assert.equals("yellow", result.colour)
  end)

  it("first match wins in storage order", function()
    local result = matcher.score_entity(
      { label = "city watchman", count = 1, mxp_colour = nil },
      {
        { pattern = "watchman", score = 3, colour = "red",  is_regex = false },
        { pattern = "city",     score = 9, colour = "blue", is_regex = false },
      },
      1
    )
    assert.equals(3, result.score)
    assert.equals("red", result.colour)
  end)

  it("preserves MXP colour when no match-list entry specifies a colour", function()
    local result = matcher.score_entity(
      { label = "george", count = 1, mxp_colour = "#ff0000" },
      {},
      1
    )
    assert.equals("#ff0000", result.colour)
  end)

  it("match-list colour overrides MXP colour", function()
    local result = matcher.score_entity(
      { label = "george", count = 1, mxp_colour = "#ff0000" },
      { { pattern = "george", score = 2, colour = "yellow", is_regex = false } },
      1
    )
    assert.equals("yellow", result.colour)
  end)

  it("falls back to SGR colour when MXP colour is absent", function()
    local result = matcher.score_entity(
      { label = "kiki", count = 1, mxp_colour = nil, sgr_colour = "#afffaf" },
      {},
      1
    )
    assert.equals("#afffaf", result.colour)
  end)

  it("prefers MXP colour over SGR colour", function()
    local result = matcher.score_entity(
      { label = "kiki", count = 1, mxp_colour = "#ff0000", sgr_colour = "#afffaf" },
      {},
      1
    )
    assert.equals("#ff0000", result.colour)
  end)
end)

describe("matcher.score_room", function()
  it("sums entity scores into total_score", function()
    local room = {
      direction = "1 n",
      entities = {
        { label = "watchman", count = 2, mxp_colour = nil },
        { label = "cat",      count = 1, mxp_colour = nil },
      },
    }
    local result = matcher.score_room(
      room,
      { { pattern = "watchman", score = 3, colour = nil, is_regex = false } },
      1  -- default
    )
    -- watchman: 3 * 2 = 6; cat: 1 * 1 = 1; total = 7
    assert.equals(7, result.total_score)
    assert.equals("1 n", result.direction)
    assert.equals(2, #result.entities)
  end)
end)
