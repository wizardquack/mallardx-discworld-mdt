local accumulator = require("accumulator")

describe("accumulator", function()
  it("handles an unwrapped single-line payload in one feed", function()
    local st = accumulator.new()
    local line = "a goat is one west, the limit of your vision is one west from here."
    local gag, payload = accumulator.feed(st, line)
    assert.is_true(gag)
    assert.equals(line, payload)
  end)

  it("handles the empty-room sentinel (no direction phrases)", function()
    local st = accumulator.new()
    local line = "The limit of your vision is here."
    local gag, payload = accumulator.feed(st, line)
    assert.is_true(gag)
    assert.equals(line, payload)
  end)

  it("reassembles a payload the server wrapped across lines", function()
    local st = accumulator.new()
    -- Mimics the ~1000-byte word-wrap: leading fragment carries no sentinel,
    -- middle fragment is bare entities, final fragment ends in "here.".
    local f1 = "an annoyed goat is one west, a shy girl is one northwest"
    local f2 = "a beggar and a bureaucrat are one northeast, a rat is one east"
    local f3 = "a hen is four east, the limit of your vision is four east from here."

    local gag, payload = accumulator.feed(st, f1)
    assert.is_true(gag)
    assert.is_nil(payload)

    gag, payload = accumulator.feed(st, f2)
    assert.is_true(gag)
    assert.is_nil(payload)

    gag, payload = accumulator.feed(st, f3)
    assert.is_true(gag)
    assert.equals(f1 .. " " .. f2 .. " " .. f3, payload)
  end)

  it("buffers the leading fragment even though it lacks the sentinel", function()
    local st = accumulator.new()
    -- A dense leading fragment with no "limit of your vision" must still gag.
    local gag = accumulator.feed(st, "a goat is one west, a cat is two southeast")
    assert.is_true(gag)
  end)

  it("ignores ordinary lines without starting a buffer", function()
    local st = accumulator.new()
    local gag, payload = accumulator.feed(st, "Multilingual Moriarty arrives from the east.")
    assert.is_false(gag)
    assert.is_nil(payload)
    -- A long directional room description must not trip it either.
    gag, payload = accumulator.feed(st,
      "Steps climb up the north and south sides; the road leads off northwards.")
    assert.is_false(gag)
    assert.is_nil(payload)
  end)

  it("trims fragments so the join restores a single space", function()
    local st = accumulator.new()
    accumulator.feed(st, "  a goat is one west, a cat is one east  ")
    local _, payload = accumulator.feed(st,
      "a hen is one north, the limit of your vision is one north from here.")
    assert.equals(
      "a goat is one west, a cat is one east " ..
      "a hen is one north, the limit of your vision is one north from here.",
      payload)
  end)

  it("flushes at MAX_FRAGMENTS if no terminator arrives", function()
    local st = accumulator.new()
    -- Dense starter (>= 2 phrases) with no terminator opens the buffer.
    local gag, payload = accumulator.feed(st, "a goat is one west, a cat is one east")
    assert.is_true(gag)
    assert.is_nil(payload)
    for _ = 2, accumulator.MAX_FRAGMENTS - 1 do
      gag, payload = accumulator.feed(st, "a rat is one east")  -- absorbed regardless
      assert.is_nil(payload)
    end
    -- The MAX_FRAGMENTS-th fragment forces a best-effort flush.
    gag, payload = accumulator.feed(st, "a cat is one west")
    assert.is_true(gag)
    assert.is_not_nil(payload)
  end)

  it("starts a fresh buffer after a payload completes", function()
    local st = accumulator.new()
    accumulator.feed(st, "a goat is one west")
    local _, p1 = accumulator.feed(st,
      "the limit of your vision is one west from here.")
    assert.is_not_nil(p1)
    -- Next dense line should begin a new payload, not append to the old one.
    local gag, p2 = accumulator.feed(st,
      "a cat is one east, the limit of your vision is one east from here.")
    assert.is_true(gag)
    assert.equals("a cat is one east, the limit of your vision is one east from here.", p2)
  end)
end)
