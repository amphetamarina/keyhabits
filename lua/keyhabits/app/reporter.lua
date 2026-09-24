-- The Reporter use case: turn a list of events into the Report that the
-- report view renders. Every count comes from the domain.

local advice = require("keyhabits.domain.advice")
local stats = require("keyhabits.domain.stats")

local M = {}

local function since(events, lower_bound)
  if lower_bound <= 0 then
    return events
  end
  return vim.tbl_filter(function(ev)
    return ev.ts >= lower_bound
  end, events)
end

local function time_span(events)
  if #events == 0 then
    return { 0, 0 }
  end
  local first, last = events[1].ts, events[1].ts
  for _, ev in ipairs(events) do
    first = math.min(first, ev.ts)
    last = math.max(last, ev.ts)
  end
  return { first, last }
end

-- Pairs are counted per session, so no pair spans two editor runs.
local function all_bigrams(events)
  local counts = {}
  for _, sequence in ipairs(stats.key_sequences(events)) do
    for gram, count in pairs(stats.ngrams(sequence, 2)) do
      counts[gram] = (counts[gram] or 0) + count
    end
  end
  return counts
end

-- Tips are matched per session, so no run spans two editor runs. Only tips
-- that resolve here are shown, and rows that save nothing are left out.
local function advice_rows(sessions, tips, resolve, limit)
  local totals = {}
  for _, commands in ipairs(sessions) do
    for id, tally in pairs(advice.match(commands, tips)) do
      local total = totals[id] or { runs = 0, saved = 0 }
      total.runs = total.runs + tally.runs
      total.saved = total.saved + tally.saved
      totals[id] = total
    end
  end
  local rows = {}
  for _, tip in ipairs(tips) do
    local total = totals[tip.id]
    local shown = total and total.saved > 0 and resolve(tip)
    if shown then
      rows[#rows + 1] = {
        id = tip.id,
        tip = shown.tip,
        help = shown.help,
        source = shown.source,
        runs = total.runs,
        saved = total.saved,
      }
    end
  end
  table.sort(rows, function(a, b)
    if a.saved ~= b.saved then
      return a.saved > b.saved
    end
    return a.id < b.id
  end)
  if limit > 0 and limit < #rows then
    return vim.list_slice(rows, 1, limit)
  end
  return rows
end

-- Commands repeated three or more times in a row that no tip looks at, so a
-- gap in the catalogue shows up in the report.
local function untipped(sessions, tips, limit)
  local presses = {}
  for _, commands in ipairs(sessions) do
    for command, tally in pairs(advice.uncovered(commands, tips)) do
      presses[command] = (presses[command] or 0) + tally.presses
    end
  end
  return stats.top(presses, limit)
end

-- options: { limit, since, tips, resolve }. resolve(tip) returns the tip as
-- shown here, or nil when it does not apply.
function M.build(events, options)
  local kept = since(events, options.since or 0)
  local limit = options.limit or 0
  local sessions = {}
  for _, session in ipairs(stats.sessions(kept)) do
    sessions[#sessions + 1] = stats.group_commands(session)
  end
  return {
    total_keys = #kept,
    sessions = #sessions,
    time_span = time_span(kept),
    advice = advice_rows(sessions, options.tips, options.resolve, limit),
    untipped = untipped(sessions, options.tips, limit),
    top_keys = stats.top(stats.count_keys(kept), limit),
    top_commands = stats.top(stats.count_commands(kept), limit),
    top_bigrams = stats.top(all_bigrams(kept), limit),
    modes = stats.top(stats.count_modes(kept), 0),
    filetypes = stats.top(stats.count_filetypes(kept), 0),
  }
end

return M
