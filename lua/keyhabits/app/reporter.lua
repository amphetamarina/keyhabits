-- The Reporter use case: turn a list of events into the Report that the
-- report view renders. Every count comes from the domain stats.

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

-- options: { limit, since }
function M.build(events, options)
  local kept = since(events, options.since or 0)
  local limit = options.limit or 0
  return {
    total_keys = #kept,
    sessions = #stats.sessions(kept),
    time_span = time_span(kept),
    top_keys = stats.top(stats.count_keys(kept), limit),
    top_commands = stats.top(stats.count_commands(kept), limit),
    top_bigrams = stats.top(all_bigrams(kept), limit),
    modes = stats.top(stats.count_modes(kept), 0),
    filetypes = stats.top(stats.count_filetypes(kept), 0),
  }
end

return M
