-- mdt subcommand dispatcher.
--
-- Registered as a single `mud.alias` on the literal command "mdt"; we
-- parse the rest of the line ourselves so the user gets useful errors
-- ("unknown subcommand: foo") instead of a silent miss.

local storage = require("storage")

local M = {}

-- Vocabulary of named colours we accept. Mirrors discworld-misc's
-- highlight colour vocabulary for cross-plugin consistency.
local COLOURS = {
  red = true, yellow = true, green = true, cyan = true, blue = true,
  magenta = true, white = true, grey = true,
  ["bold-red"] = true, ["bold-yellow"] = true, ["bold-green"] = true,
  ["bold-cyan"] = true, ["bold-blue"] = true, ["bold-magenta"] = true,
  ["bold-white"] = true,
}

local function info(msg)
  mud.note("[mdt] " .. msg)
end

local function err(msg)
  mud.note("[mdt] " .. msg, { fg = "red" })
end

local function usage()
  info("usage:")
  info("  mdt                     this message")
  info("  mdt help                this message")
  info("  mdt list [pattern]      show match list")
  info("  mdt add <pat> [score] [colour]")
  info("  mdt remove <pat>|<n>    remove by exact pattern or 1-based index")
  info("  mdt clear               wipe match list (this character)")
end

-- Parse a user-supplied pattern token. Returns (pattern, is_regex).
-- /.../  → regex. Otherwise: lowercased substring.
local function parse_pattern(tok)
  local inner = tok:match("^/(.+)/$")
  if inner then return inner, true end
  return tok:lower(), false
end

local function cmd_list(args)
  local filter = args:match("^%s*(.-)%s*$")
  local list = storage.load()
  if #list == 0 then
    info("match list is empty.")
    return
  end
  for i, entry in ipairs(list) do
    if filter == "" or entry.pattern:find(filter, 1, true) then
      local pat = entry.is_regex and ("/" .. entry.pattern .. "/") or entry.pattern
      local colour = entry.colour and (" " .. entry.colour) or ""
      info(string.format("  %d. %s [%d]%s", i, pat, entry.score, colour))
    end
  end
end

local function cmd_add(args)
  local pat_tok, score_tok, colour_tok = args:match("^(%S+)%s*(%S*)%s*(%S*)$")
  if not pat_tok or pat_tok == "" then
    err("usage: mdt add <pattern> [score] [colour]")
    return
  end
  local pattern, is_regex = parse_pattern(pat_tok)
  local score = 1
  if score_tok ~= "" then
    score = tonumber(score_tok)
    if not score then
      err("score must be a number (got: " .. score_tok .. ")")
      return
    end
  end
  local colour = nil
  if colour_tok ~= "" then
    if not COLOURS[colour_tok] then
      err("unknown colour: " .. colour_tok .. ". try: " ..
        table.concat({"red","yellow","green","cyan","blue","magenta","white","grey"}, ", "))
      return
    end
    colour = colour_tok
  end
  storage.add({
    pattern = pattern,
    score = score,
    colour = colour,
    is_regex = is_regex,
  })
  info("added: " .. (is_regex and ("/" .. pattern .. "/") or pattern) ..
    " score=" .. score .. (colour and (" colour=" .. colour) or ""))
end

local function cmd_remove(args)
  local tok = args:match("^%s*(.-)%s*$")
  if tok == "" then
    err("usage: mdt remove <pattern>|<index>")
    return
  end
  -- Numeric index?
  local idx = tonumber(tok)
  if idx then
    local _, removed = storage.remove_at(idx)
    if removed then
      info("removed entry #" .. idx)
    else
      err("no entry at index " .. idx)
    end
    return
  end
  -- Exact pattern. Handle /.../ form.
  local pattern = parse_pattern(tok)
  local _, removed = storage.remove_by_pattern(pattern)
  if removed then
    info("removed: " .. tok)
  else
    err("no entry matches: " .. tok)
  end
end

local function cmd_clear()
  storage.clear()
  info("match list cleared.")
end

local function dispatch(m)
  -- `m` is a LuaMatch userdata. m[1] is the (.*) capture group from our
  -- "^mdt(.*)$" alias pattern — i.e. the rest of the line after "mdt".
  -- Trim leading whitespace to handle both "mdt" and "mdt foo".
  local rest = (m[1] or ""):gsub("^%s+", "")
  if rest == "" then
    usage()
    return
  end
  local sub, sub_args = rest:match("^(%S+)%s*(.*)$")
  sub_args = sub_args or ""
  if sub == "help" then usage()
  elseif sub == "list" then cmd_list(sub_args)
  elseif sub == "add" then cmd_add(sub_args)
  elseif sub == "remove" or sub == "rm" then cmd_remove(sub_args)
  elseif sub == "clear" then cmd_clear()
  else
    err("unknown subcommand: " .. sub)
    usage()
  end
end

function M.register()
  -- Glob pattern: "mdt" optionally followed by anything. Captures whole line.
  mud.alias("^mdt(.*)$", dispatch)
end

return M
