-- A pure matcher of tips over lists of commands.
--
-- A tip matches a run of consecutive commands, because SafeState ends a
-- command after every plain motion: "jjjj" arrives as four "j" commands. The
-- fields a tip uses are described in keyhabits.domain.tips.

local event = require("keyhabits.domain.event")

local M = {}

-- Compiled Vim regexes, by pattern. vim.regex() is case-sensitive whatever
-- 'ignorecase' says, which is what a key name needs.
local compiled = {}

local function regex(pattern)
  local re = compiled[pattern]
  if not re then
    re = vim.regex(pattern)
    compiled[pattern] = re
  end
  return re
end

local function matches(command, pattern)
  return regex(pattern):match_str(command) ~= nil
end

-- Keys typed for a command. Typed text is left out: it is the same whichever
-- way the command is written.
function M.key_count(command)
  local without_text = command:gsub(vim.pesc(event.PLACEHOLDER), "")
  local keys = without_text:gsub("<[^<>]+>", ".")
  return vim.fn.strcharlen(keys)
end

local function run_keys(commands, first, last)
  local total = 0
  for index = first, last do
    total = total + M.key_count(commands[index])
  end
  return total
end

local function sequence_at(commands, start, sequence)
  if start + #sequence - 1 > #commands then
    return false
  end
  for offset, pattern in ipairs(sequence) do
    if not matches(commands[start + offset - 1], pattern) then
      return false
    end
  end
  return true
end

local function same_as_first(commands, first, index, size)
  for offset = 0, size - 1 do
    if commands[index + offset] ~= commands[first + offset] then
      return false
    end
  end
  return true
end

-- How many commands a run of the tip consumes at start, or 0 if the tip does
-- not match there. A tip with min 1 matches one occurrence at a time.
local function run_length(commands, start, tip)
  local sequence = tip.sequence
  local index, repeats = start, 0
  while sequence_at(commands, index, sequence) and (repeats == 0 or tip.min > 1) do
    if repeats > 0 and tip.same and not same_as_first(commands, start, index, #sequence) then
      break
    end
    index = index + #sequence
    repeats = repeats + 1
  end
  if repeats >= tip.min then
    return index - start, repeats
  end
  return 0, 0
end

-- How many commands a tip with repeats consumes at start: each regex takes as
-- many commands in a row as it matches, at least its minimum; 0 when one falls
-- short.
local function steps_length(commands, start, tip)
  local index = start
  for step, pattern in ipairs(tip.sequence) do
    local count = 0
    while index <= #commands and matches(commands[index], pattern) do
      index = index + 1
      count = count + 1
    end
    if count < tip.repeats[step] then
      return 0
    end
  end
  return index - start
end

-- The parts of one command an inside tip matches, left to right.
local function parts(command, pattern)
  local found = {}
  local start = 0
  while true do
    local hit = vim.fn.matchstrpos(command, [[\C]] .. pattern, start)
    if hit[2] < 0 then
      return found
    end
    found[#found + 1] = hit[1]
    start = hit[3]
  end
end

local function saved(tip, keys, repeats)
  if tip.saves then
    return tip.saves
  end
  return math.max(0, keys - tip.fix - (tip.fix_each or 0) * (repeats - 1))
end

local function add(found, id, runs, keys_saved)
  local tally = found[id] or { runs = 0, saved = 0 }
  tally.runs = tally.runs + runs
  tally.saved = tally.saved + keys_saved
  found[id] = tally
end

-- How many commands the tip takes at index, adding what it found; 0 when it
-- does not match there.
local function take(commands, index, tip, found)
  if tip.repeats then
    local length = steps_length(commands, index, tip)
    if length > 0 then
      add(found, tip.id, 1, saved(tip, run_keys(commands, index, index + length - 1), 1))
    end
    return length
  end
  if tip.inside then
    local hits = parts(commands[index], tip.sequence[1])
    for _, part in ipairs(hits) do
      add(found, tip.id, 1, saved(tip, M.key_count(part), 1))
    end
    return #hits > 0 and 1 or 0
  end
  local length, repeats = run_length(commands, index, tip)
  if length > 0 then
    add(found, tip.id, 1, saved(tip, run_keys(commands, index, index + length - 1), repeats))
  end
  return length
end

-- Which tips can start at a command depends only on the command, and the same
-- few commands repeat, so each distinct one is checked against a list of tips
-- once and the answer remembered for that list. Forgotten when it grows
-- large, since typed variations such as f{char} make commands open-ended.
local max_remembered = 2000
local starters_by_list = setmetatable({}, { __mode = "k" })

local function starters(tips, command)
  local memo = starters_by_list[tips]
  if not memo or memo.size > max_remembered then
    memo = { size = 0, by_command = {} }
    starters_by_list[tips] = memo
  end
  local found = memo.by_command[command]
  if not found then
    found = {}
    for _, tip in ipairs(tips) do
      if matches(command, tip.sequence[1]) then
        found[#found + 1] = tip
      end
    end
    memo.by_command[command] = found
    memo.size = memo.size + 1
  end
  return found
end

-- Scans the commands once. At each position the first tip that matches wins
-- and its run is consumed, so a run is counted once. Returns, per tip id, the
-- number of runs and the keys the better way would have saved.
function M.match(commands, tips)
  local found = {}
  local index = 1
  while index <= #commands do
    local consumed = 0
    for _, tip in ipairs(starters(tips, commands[index])) do
      consumed = take(commands, index, tip, found)
      if consumed > 0 then
        break
      end
    end
    index = index + math.max(consumed, 1)
  end
  return found
end

-- A command is covered when some tip looks at it at all, even if this run was
-- too short for the tip.
local function is_covered(command, tips)
  for _, tip in ipairs(tips) do
    for _, pattern in ipairs(tip.sequence) do
      if matches(command, pattern) then
        return true
      end
    end
  end
  return false
end

-- Runs of the same command, three or more in a row, that no tip covers: the
-- gaps in the catalogue. Returns, per command, the runs and the presses.
function M.uncovered(commands, tips)
  local found = {}
  local index = 1
  while index <= #commands do
    local next_index = index
    while next_index <= #commands and commands[next_index] == commands[index] do
      next_index = next_index + 1
    end
    local length = next_index - index
    if length >= 3 and not is_covered(commands[index], tips) then
      local tally = found[commands[index]] or { runs = 0, presses = 0 }
      tally.runs = tally.runs + 1
      tally.presses = tally.presses + length
      found[commands[index]] = tally
    end
    index = next_index
  end
  return found
end

return M
