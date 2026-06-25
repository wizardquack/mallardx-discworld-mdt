-- Inline map-door-text accumulator.
--
-- Discworld word-wraps the textual `map door text` output at ~1000 bytes, so a
-- dense payload arrives as several consecutive physical lines, the last of
-- which ends in the vision sentinel "... here.". The old inline trigger was a
-- single-line, `$`-anchored regex, so it only ever saw that final fragment and
-- silently dropped everything before it (see parser.direction_density and the
-- investigation in git history).
--
-- This pure state machine reassembles the fragments. It is fed one server line
-- at a time and returns:
--   gag     — whether the caller should suppress this raw line
--   payload — non-nil when a complete map-door-text payload has just been
--             reassembled; the caller scores + renders it
--
-- Detection avoids the sentinel entirely (the leading fragment may lack it) and
-- keys off direction-phrase density instead, which uniquely marks MDT content.
-- Once buffering has started, every subsequent line is absorbed until one ends
-- in "here." (the true end-of-payload marker — intermediate sentinels end in
-- "here," with a comma, so they never false-trigger the flush). MAX_FRAGMENTS
-- bounds the damage if a terminator never arrives.

local parser = require("parser")

local M = {}

-- A line scoring at least this many "<count> <direction>" phrases starts a
-- buffer. 2 sits far below any real fragment (>= 22 observed) and far above
-- every non-MDT line (0 observed across a week of logs).
M.DENSITY_THRESHOLD = 2

-- Safety valve: a real wrapped payload is at most a handful of fragments. If we
-- somehow buffer this many without seeing the "here." terminator, flush what we
-- have rather than gagging the rest of the session.
M.MAX_FRAGMENTS = 8

function M.new()
  return { buffer = {} }
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- True end-of-payload: a fragment ending in "here." (period). Intermediate
-- sentinels read "... from here, <more>" and the wrap breaks mid-word, so only
-- the final fragment ever ends in a bare "here.".
local function ends_payload(s)
  return s:match("here%.$") ~= nil
end

-- An idle-state line worth buffering: dense entity content, or the bare vision
-- sentinel for an empty room ("The limit of your vision is here.") which scores
-- no direction phrases but should still be gagged + handled.
local function starts_payload(s)
  if parser.direction_density(s) >= M.DENSITY_THRESHOLD then return true end
  if s:lower():match("the limit of your vision is .*here%.$") then return true end
  return false
end

-- Feed one server line. Returns (gag, payload).
function M.feed(st, text)
  local line = trim(text)

  if #st.buffer > 0 then
    -- Mid-payload: absorb everything until the terminator (fragments arrive
    -- contiguously, so no foreign line interleaves in practice).
    st.buffer[#st.buffer + 1] = line
    if ends_payload(line) or #st.buffer >= M.MAX_FRAGMENTS then
      local payload = table.concat(st.buffer, " ")
      st.buffer = {}
      return true, payload
    end
    return true, nil
  end

  if starts_payload(line) then
    st.buffer[#st.buffer + 1] = line
    if ends_payload(line) then
      -- Unwrapped single-line payload: complete immediately.
      local payload = st.buffer[1]
      st.buffer = {}
      return true, payload
    end
    return true, nil
  end

  return false, nil
end

return M
