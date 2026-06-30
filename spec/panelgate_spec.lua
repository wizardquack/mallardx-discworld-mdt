local panelgate = require("panelgate")

-- Two scored-room lists that describe the same rooms collapse to the same
-- signature, so whichever pipeline (GMCP frame vs inline map-door-text)
-- posts second is suppressed and the "Nearby" panel is driven once per move.
describe("panelgate.signature", function()
  it("is stable for structurally identical room lists", function()
    local a = {
      { direction = "one west", score = 3,
        entities = { { label = "goat", count = 1, colour = "red" } } },
    }
    local b = {
      { direction = "one west", score = 3,
        entities = { { label = "goat", count = 1, colour = "red" } } },
    }
    assert.equals(panelgate.signature(a), panelgate.signature(b))
  end)

  it("changes when an entity count changes", function()
    local a = { { direction = "n", score = 1,
      entities = { { label = "rat", count = 1, colour = nil } } } }
    local b = { { direction = "n", score = 1,
      entities = { { label = "rat", count = 2, colour = nil } } } }
    assert.are_not.equal(panelgate.signature(a), panelgate.signature(b))
  end)

  it("changes when a score changes (match-list edit re-scores same room)", function()
    local a = { { direction = "n", score = 1, entities = {} } }
    local b = { { direction = "n", score = 9, entities = {} } }
    assert.are_not.equal(panelgate.signature(a), panelgate.signature(b))
  end)

  it("changes when a colour changes", function()
    local a = { { direction = "n", score = 1,
      entities = { { label = "watchman", count = 1, colour = nil } } } }
    local b = { { direction = "n", score = 1,
      entities = { { label = "watchman", count = 1, colour = "red" } } } }
    assert.are_not.equal(panelgate.signature(a), panelgate.signature(b))
  end)

  it("does not collide across an entity-label / direction boundary", function()
    -- "ab" in one field must not equal "a" + "b" split across fields.
    local a = { { direction = "ab", score = 0, entities = {} } }
    local b = { { direction = "a", score = 0,
      entities = { { label = "b", count = 0, colour = nil } } } }
    assert.are_not.equal(panelgate.signature(a), panelgate.signature(b))
  end)
end)

describe("panelgate.should_post", function()
  it("posts the first time and suppresses an identical follow-up", function()
    local gate = panelgate.new()
    local rooms = { { direction = "one west", score = 3,
      entities = { { label = "goat", count = 1, colour = "red" } } } }
    assert.is_true(panelgate.should_post(gate, rooms))
    -- Second pipeline produces the same rooms this move → suppressed.
    assert.is_false(panelgate.should_post(gate, { { direction = "one west", score = 3,
      entities = { { label = "goat", count = 1, colour = "red" } } } }))
  end)

  it("re-posts once the room set actually changes", function()
    local gate = panelgate.new()
    assert.is_true(panelgate.should_post(gate, { { direction = "n", score = 1, entities = {} } }))
    assert.is_false(panelgate.should_post(gate, { { direction = "n", score = 1, entities = {} } }))
    assert.is_true(panelgate.should_post(gate, { { direction = "s", score = 1, entities = {} } }))
  end)

  it("treats an empty room list as a postable state", function()
    local gate = panelgate.new()
    assert.is_true(panelgate.should_post(gate, {}))
    assert.is_false(panelgate.should_post(gate, {}))
  end)
end)
