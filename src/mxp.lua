-- MXP unwrap — extract name + colour from Discworld's writtenmap MXP wrappers.
--
-- Shape (from Quow's QuowMinimap.xml:18181-18205):
--   \27[4zmxp<c #rrggbbmxp>NAME\27[3z   hex colour
--   \27[4zmxp<colourmxp>NAME\27[3z      named colour
--   Two adjacent wrappers wrap player+title; outer colour wins.

local M = {}

-- Match exactly one wrapper at the start of `s`. Returns (inner, colour) or
-- (nil, nil) if `s` does not start with a wrapper.
local function match_wrapper(s)
  -- Capture: colour-spec inside <...mxp>, then inner up to \27[3z.
  -- Lua patterns: \27 = escape (0x1b). [^>] is fine; "mxp" is the closer
  -- marker for the colour attribute.
  local colour_spec, inner = s:match("^\27%[4zmxp<(.-)mxp>(.-)\27%[3z$")
  if colour_spec and inner then
    -- "c #rrggbb" → strip the leading "c "
    if colour_spec:sub(1, 2) == "c " then
      colour_spec = colour_spec:sub(3)
    end
    return inner, colour_spec
  end
  return nil, nil
end

-- Unwrap a single entity string. If it is exactly one (or two nested) MXP
-- wrappers, return (name, colour). Otherwise return (s, nil).
function M.unwrap_one(s)
  local inner, colour = match_wrapper(s)
  if not inner then return s, nil end
  -- Check for nested wrapper (player + title case).
  local inner2 = match_wrapper(inner)
  if inner2 then
    -- Outer colour wins; strip the inner wrapper from the name.
    return inner2, colour
  end
  return inner, colour
end

return M
