-- Matcher: entity + user match list → {label, count, score, colour}.
--
-- Pure module. Match list is an ordered array of
--   { pattern = string, score = number, colour = string|nil, is_regex = bool }
-- First match in storage order wins. Default score (config) is used when
-- no entry matches.

local M = {}

local function matches(label, entry)
  if entry.is_regex then
    return label:find(entry.pattern) ~= nil
  else
    -- Lua's string.find with `plain=true` does a literal substring search.
    return label:find(entry.pattern, 1, true) ~= nil
  end
end

-- Score one entity. Returns a fresh record with computed score + colour.
-- The label is lowercased upstream (parser.normalise); matching here is
-- therefore case-sensitive in regex mode but de-facto case-insensitive
-- because the parser already lowercased everything.
function M.score_entity(entity, match_list, default_score)
  local result = {
    label = entity.label,
    count = entity.count,
    score = default_score,
    colour = entity.mxp_colour or entity.sgr_colour,  -- baseline; may be overwritten by match
  }
  for _, entry in ipairs(match_list) do
    if matches(entity.label, entry) then
      result.score = entry.score
      if entry.colour and entry.colour ~= "" then
        result.colour = entry.colour
      end
      break
    end
  end
  return result
end

-- Score one room. Multiplies entity score by count for the total.
function M.score_room(room, match_list, default_score)
  local scored_entities = {}
  local total = 0
  for _, entity in ipairs(room.entities) do
    local scored = M.score_entity(entity, match_list, default_score)
    scored_entities[#scored_entities + 1] = scored
    total = total + (scored.score * scored.count)
  end
  return {
    direction = room.direction,
    entities = scored_entities,
    total_score = total,
  }
end

return M
