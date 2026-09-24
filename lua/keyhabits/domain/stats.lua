-- Pure statistics over lists of Events. Nothing here touches files,
-- autocommands, timers or options: events in, plain data out.

local event = require("keyhabits.domain.event")

local M = {}

local none_label = "[none]"

local function count_names(names)
  local counts = {}
  for _, name in ipairs(names) do
    counts[name] = (counts[name] or 0) + 1
  end
  return counts
end

local function names_of(events, field)
  local names = {}
  for _, ev in ipairs(events) do
    names[#names + 1] = ev[field]
  end
  return names
end

-- Events belong to the same command when session and group number match.
local function same_group(a, b)
  return a.sid == b.sid and a.grp == b.grp
end

-- A command is started in Normal mode or in the Visual family (v, V, CTRL-V).
local function is_command_mode(mode)
  return mode == "\22" or (mode ~= "" and ("nvV"):find(mode:sub(1, 1), 1, true) ~= nil)
end

-- A run of consecutive placeholders counts as one habit, so i<text><text><Esc>
-- and i<text><Esc> are the same command.
local function collapse(names)
  local collapsed = {}
  for _, name in ipairs(names) do
    if not (name == event.PLACEHOLDER and collapsed[#collapsed] == event.PLACEHOLDER) then
      collapsed[#collapsed + 1] = name
    end
  end
  return collapsed
end

function M.count_keys(events)
  return count_names(names_of(events, "typed"))
end

function M.count_modes(events)
  return count_names(names_of(events, "mode"))
end

function M.count_filetypes(events)
  local names = {}
  for _, ft in ipairs(names_of(events, "ft")) do
    names[#names + 1] = ft == "" and none_label or ft
  end
  return count_names(names)
end

function M.group_commands(events)
  local commands = {}
  local index = 1
  while index <= #events do
    local first = events[index]
    local names = {}
    while index <= #events and same_group(events[index], first) do
      names[#names + 1] = events[index].typed
      index = index + 1
    end
    if is_command_mode(first.mode) then
      commands[#commands + 1] = table.concat(collapse(names))
    end
  end
  return commands
end

function M.count_commands(events)
  return count_names(M.group_commands(events))
end

-- Events per session, in the order each session first appears. Two editors
-- running at once interleave their batches in the log, so a session is
-- gathered wherever its events are.
function M.sessions(events)
  local by_id, order = {}, {}
  for _, ev in ipairs(events) do
    if not by_id[ev.sid] then
      by_id[ev.sid] = {}
      order[#order + 1] = ev.sid
    end
    table.insert(by_id[ev.sid], ev)
  end
  local sessions = {}
  for _, sid in ipairs(order) do
    sessions[#sessions + 1] = by_id[sid]
  end
  return sessions
end

function M.ngrams(keys, n)
  if n < 1 then
    error("keyhabits.stats: n must be at least 1", 0)
  end
  local counts = {}
  for start = 1, #keys - n + 1 do
    local gram = table.concat(keys, "", start, start + n - 1)
    counts[gram] = (counts[gram] or 0) + 1
  end
  return counts
end

-- The typed keys of each session, with runs of typed text collapsed.
function M.key_sequences(events)
  local sequences = {}
  for _, session in ipairs(M.sessions(events)) do
    sequences[#sequences + 1] = collapse(names_of(session, "typed"))
  end
  return sequences
end

-- Pairs of { name, count }, by count descending and then by name, so that
-- reports are stable across runs. A limit of 0 or less keeps everything.
function M.top(counts, limit)
  local pairs_list = {}
  for name, count in pairs(counts) do
    pairs_list[#pairs_list + 1] = { name, count }
  end
  table.sort(pairs_list, function(a, b)
    if a[2] ~= b[2] then
      return a[2] > b[2]
    end
    return a[1] < b[1]
  end)
  if limit > 0 and limit < #pairs_list then
    return vim.list_slice(pairs_list, 1, limit)
  end
  return pairs_list
end

return M
