-- Inline map-door-text trigger. Catches the textual sentinel line that
-- Discworld emits when `map door text` is invoked, gags the raw output,
-- and re-emits a styled, scored version via mud.note + mud.span.

local pipeline = require("pipeline")

local M = {}

-- Match-list named colours mapped to hex equivalents that visually match
-- panel.css's .c-* classes. mud.span's `fg` accepts hex or ANSI-16 palette
-- names, but our `grey` and `bold-*` vocabulary doesn't line up 1:1 with
-- Mallard's palette — hex keeps the inline output identical to the panel.
local NAMED_HEX = {
  red     = "#ff5555",
  yellow  = "#ffdd55",
  green   = "#55ff55",
  cyan    = "#55ffff",
  blue    = "#8888ff",
  magenta = "#ff55ff",
  white   = "#ffffff",
  grey    = "#888888",
}

local function colour_to_style(colour)
  if not colour or colour == "" then return {} end
  if colour:sub(1, 1) == "#" then return { fg = colour } end
  local bold_name = colour:match("^bold%-(.+)$")
  if bold_name then
    return { fg = NAMED_HEX[bold_name] or bold_name, bold = true }
  end
  return { fg = NAMED_HEX[colour] or colour }
end

-- Tighten "1 nw, 2 w" → "nw, 2w" (mirrors panel.js's formatDirection so
-- inline and panel rendering stay consistent).
local function format_direction(s)
  local parts = {}
  for raw in s:gmatch("[^,]+") do
    local tok = raw:gsub("^%s+", ""):gsub("%s+$", "")
    local n, d = tok:match("^(%d+) (%S+)$")
    if n and d then
      parts[#parts + 1] = (n == "1") and d or (n .. d)
    else
      parts[#parts + 1] = tok
    end
  end
  return table.concat(parts, ", ")
end

local function emit_row(dir_str, dir_width, room)
  -- Use string.format("%d", …) for numeric columns: Mallard settings of
  -- type="number" come back as Lua floats (settings.rs stores them as
  -- f64), so score arithmetic yields floats. Lua's `..` concat formats
  -- those as "2.0"; the panel side hides this because JS doesn't render
  -- the trailing zero, but inline notes go through Lua tostring.
  local spans = {
    mud.span(string.format("%-" .. dir_width .. "s ", dir_str), { fg = "#88aaff", bold = true }),
    mud.span(string.format("[%d] ", room.total_score), { fg = "#888888" }),
  }
  for i, e in ipairs(room.entities) do
    if i > 1 then
      spans[#spans + 1] = mud.span(", ", { fg = "#555555" })
    end
    local label = (e.count > 1) and (string.format("%d %s", e.count, e.label)) or e.label
    spans[#spans + 1] = mud.span(label, colour_to_style(e.colour))
  end
  mud.note(table.unpack(spans))
end

function M.register()
  -- Mallard trigger patterns are Rust regex (not Lua patterns). The `.*`
  -- between "is " and "here." (not `.+`) lets the empty-rooms case match:
  -- "the limit of your vision is here." with no preceding entities.
  mud.trigger("the limit of your vision is .*here\\.$", function(m)
    m:gag()
    local scored = pipeline.score_payload(m.text)
    -- Pre-compute formatted directions so we can align the score column
    -- to the widest direction across this batch of rooms.
    local rows = {}
    local max_dir_width = 0
    for _, room in ipairs(scored) do
      local dir = format_direction(room.direction)
      if #dir > max_dir_width then max_dir_width = #dir end
      rows[#rows + 1] = { dir = dir, room = room }
    end
    for _, r in ipairs(rows) do
      emit_row(r.dir, max_dir_width, r.room)
    end
  end)
end

return M
