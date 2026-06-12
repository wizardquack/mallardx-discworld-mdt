-- Parser for Discworld's room.writtenmap GMCP payload.
--
-- See spec/fixtures for canned payloads. The algorithm mirrors tt_dw's
-- parse_mdt (~/code/3p/tt_dw/scripts/map/mdt.tin:548-629) and Quow's
-- ParseMDT (~/code/3p/quow-reference/QuowMinimap.xml:18059+) — read those
-- as cross-reference if the behaviour here is unclear.

local M = {}

-- Number-words 0..20 are sufficient for MDT entity counts; we won't see
-- "two hundred bystanders" in practice.
local NUMBER_WORDS = {
  zero = 0, one = 1, two = 2, three = 3, four = 4, five = 5, six = 6,
  seven = 7, eight = 8, nine = 9, ten = 10, eleven = 11, twelve = 12,
  thirteen = 13, fourteen = 14, fifteen = 15, sixteen = 16,
  seventeen = 17, eighteen = 18, nineteen = 19, twenty = 20,
}

local DIRECTIONS = {
  n = true, s = true, e = true, w = true,
  ne = true, nw = true, se = true, sw = true,
  u = true, d = true,
  north = true, south = true, east = true, west = true,
  northeast = true, northwest = true, southeast = true, southwest = true,
  up = true, down = true,
}

-- Lowercase, collapse conjunctions, mark vision sentinel. Order matters:
-- the vision sentinel rewrite must precede the " is " → ", " rewrite
-- (otherwise "vision is" gets split incorrectly). MXP wrappers are NOT
-- touched here — parse() handles them separately via a tag-and-restore
-- pass that preserves the colour metadata.
function M.normalise(s)
  s = s:lower()
  s = s:gsub("the limit of your vision is ", "the limit of your vision: ")
  s = s:gsub(" are ", " is ")
  s = s:gsub(" and ", ", ")
  s = s:gsub(" is ", ", ")
  return s
end

-- Pull a leading count (digit or word) and an optional leading article.
-- Returns (count, remainder). If no count prefix is present, returns
-- (1, original-with-leading-article-stripped).
function M.parse_count(s)
  local count = 1
  -- Try numeric prefix.
  local digits, after = s:match("^(%d+) (.*)$")
  if digits then
    count = tonumber(digits)
    s = after
  else
    -- Try word prefix.
    local word, after_word = s:match("^(%a+) (.*)$")
    if word and NUMBER_WORDS[word] then
      count = NUMBER_WORDS[word]
      s = after_word
    end
  end
  -- Strip leading article.
  s = s:gsub("^a ", ""):gsub("^an ", ""):gsub("^the ", "")
  return count, s
end

function M.is_direction(s)
  return DIRECTIONS[s] == true
end

return M
