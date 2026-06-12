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
--
-- The final step joins back-to-back payloads: a real writtenmap string
-- ends with "here." and a subsequent payload begins after ". ". Replacing
-- "here. " with "here, " makes the gmatch comma-splitter see them as one
-- flat stream of segments (tested by the "flushes on the vision sentinel"
-- case in parser_spec.lua).
function M.normalise(s)
  s = s:lower()
  s = s:gsub("the limit of your vision is ", "the limit of your vision: ")
  s = s:gsub(" are ", " is ")
  s = s:gsub(" and ", ", ")
  s = s:gsub(" is ", ", ")
  s = s:gsub("here%. ", "here, ")
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

-- Detect a door/exit segment by prefix. After parse_count strips count +
-- article, a segment like "door" / "doors" / "exit" / "exits" / "hard to
-- see through exit" / "exit south of one west" all qualify. Word-boundary
-- check (space or end-of-string) avoids false positives on hypothetical
-- NPCs like "doorman" or "exitsmith".
local function is_door_segment(rest)
  for _, keyword in ipairs({"door", "doors", "exit", "exits", "hard to see through exit"}) do
    if rest == keyword or rest:sub(1, #keyword + 1) == keyword .. " " then
      return true
    end
  end
  return false
end

-- Short forms of every direction word the walker may encounter.
local SHORT_DIRECTION = {
  n = "n", s = "s", e = "e", w = "w",
  ne = "ne", nw = "nw", se = "se", sw = "sw",
  u = "u", d = "d",
  north = "n", south = "s", east = "e", west = "w",
  northeast = "ne", northwest = "nw", southeast = "se", southwest = "sw",
  up = "u", down = "d",
}

function M.short_direction(d) return SHORT_DIRECTION[d] or d end

-- Walk a normalised, MXP-tagged payload as a comma-separated stream of
-- segments, producing a list of room records.
--
-- State (mirrors tt_dw mdt.tin:570-625):
--   direction       — accumulated short-form direction, e.g. "1 n" or
--                     "1 n, 2 e" if multiple distances are merged
--   entities        — list of {raw, label, mxp_colour, count}
--   last_was_dir    — previous segment was a direction. A direction →
--                     entity transition flushes the current room (the
--                     entity belongs to the *next* room).
--   ignoring_exits  — true while consuming a door/exit phrase and its
--                     trailing direction. Reset by any non-direction.
function M.parse(input)
  if input == nil or input == "" then return {} end

  -- Stage 1: replace each MXP wrapper with "\1IDX\2NAME\1" so the
  -- name survives normalisation as a single non-letter-bounded token,
  -- and the colour can be looked up by index later. Doubled wrappers
  -- (player + title, e.g. `\27[4zmxp<#aaamxp>\27[4zmxp<#bbbmxp>NAME\27[3z\27[3z`)
  -- must be handled BEFORE the single-wrapper pattern, otherwise the
  -- single pattern's lazy `.-` swallows the inner wrapper into the name.
  -- For doubled wrappers the OUTER colour wins.
  local colour_registry = {}
  local function record_colour(colour_spec, name)
    if colour_spec:sub(1, 2) == "c " then colour_spec = colour_spec:sub(3) end
    local idx = #colour_registry + 1
    colour_registry[idx] = colour_spec
    return "\1" .. idx .. "\2" .. name .. "\1"
  end
  -- Pass A: doubled wrappers. Outer colour is captured; inner colour
  -- (capture group 2) is discarded by ignoring it in the replacement.
  local tagged = input:gsub(
    "\27%[4zmxp<(.-)mxp>\27%[4zmxp<(.-)mxp>(.-)\27%[3z\27%[3z",
    function(outer_colour, _inner_colour, name)
      return record_colour(outer_colour, name)
    end)
  -- Pass B: any remaining single wrappers.
  tagged = tagged:gsub(
    "\27%[4zmxp<(.-)mxp>(.-)\27%[3z",
    record_colour)

  -- Stage 2: standard normalisation (lowercase, conjunctions → comma,
  -- sentinel marker). MXP markers are non-letter and unaffected.
  local normalised = M.normalise(tagged)

  -- Stage 3: walk.
  local rooms = {}
  local direction = ""
  local entities = {}
  local last_was_dir = false
  local ignoring_exits = false

  local function flush_room()
    if #entities > 0 then
      rooms[#rooms + 1] = {
        direction = direction:gsub("^%s+", ""):gsub("%s+$", ""),
        entities = entities,
      }
    end
    direction = ""
    entities = {}
    last_was_dir = false
    ignoring_exits = false
  end

  for raw_seg in normalised:gmatch("([^,]+)") do
    local segment = raw_seg:gsub("^%s+", ""):gsub("%s+$", "")
    if segment == "" then
      -- skip
    elseif segment:match("^the limit of your vision:") then
      flush_room()
    else
      local count, rest = M.parse_count(segment)

      if is_door_segment(rest) then
        -- A door / exit reference (bare or with embellishments like
        -- "exit south of one west"). Suppress the direction that
        -- follows so it doesn't become a "room" of its own.
        ignoring_exits = true
      else
        local first_word = rest:match("^([%a]+)")
        if first_word and M.is_direction(first_word) then
          if ignoring_exits then
            -- Silently consumed.
          else
            local short = M.short_direction(first_word)
            if direction ~= "" then direction = direction .. ", " end
            direction = direction .. count .. " " .. short
            last_was_dir = true
          end
        else
          -- Entity. A direction → entity transition means the previous
          -- room is complete; flush it before adding this entity to the
          -- new (empty) room.
          ignoring_exits = false
          if last_was_dir then flush_room() end

          -- Recover MXP colour if the segment carries our marker.
          local mxp_colour = nil
          local label = rest
          local idx_str, name_part = rest:match("^\1(%d+)\2(.+)\1$")
          if idx_str then
            mxp_colour = colour_registry[tonumber(idx_str)]
            label = name_part
          end

          -- Strip any embedded ANSI SGR sequences from the label.
          -- Discworld emits per-user auto-colouring as raw SGR (e.g.
          -- "\27[38;5;157mNAME\27[39;49m\27[0m") inside MXP wrappers.
          -- The user's match list rules entity colour, not server SGR.
          label = (label:gsub("\27%[[0-9;]*m", ""))

          entities[#entities + 1] = {
            raw = segment,
            label = label,
            mxp_colour = mxp_colour,
            count = count,
          }
        end
      end
    end
  end

  -- Trailing flush in case input didn't end with the sentinel.
  flush_room()

  return rooms
end

return M
