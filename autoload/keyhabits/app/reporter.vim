vim9script

# The Reporter use case: turn a list of events into the Report data structure
# that the report buffer renders. Every count comes from the domain stats.

import autoload 'keyhabits/domain/advice.vim'
import autoload 'keyhabits/domain/stats.vim'

export def Build(events: list<dict<any>>, options: dict<any>): dict<any>
  var kept: list<dict<any>> = Since(events, get(options, 'since', 0))
  var limit: number = get(options, 'limit', 0)
  var sessions: list<list<string>> = SessionCommands(kept)
  return {
    total_keys: len(kept),
    sessions: Sessions(kept),
    time_span: TimeSpan(kept),
    top_keys: stats.Top(stats.CountKeys(kept), limit),
    top_commands: stats.Top(stats.CountCommands(kept), limit),
    top_bigrams: stats.Top(AllBigrams(kept), limit),
    modes: stats.Top(stats.CountModes(kept), 0),
    filetypes: stats.Top(stats.CountFiletypes(kept), 0),
    advice: Advice(sessions, limit),
    untipped: Untipped(sessions, limit),
  }
enddef

def Since(events: list<dict<any>>, since: number): list<dict<any>>
  if since <= 0
    return events
  endif
  var kept: list<dict<any>> = []
  for ev in events
    if ev.ts >= since
      add(kept, ev)
    endif
  endfor
  return kept
enddef

def Sessions(events: list<dict<any>>): number
  var seen: dict<bool> = {}
  for ev in events
    seen[ev.sid] = true
  endfor
  return len(seen)
enddef

def TimeSpan(events: list<dict<any>>): list<number>
  if len(events) == 0
    return [0, 0]
  endif
  var first: number = events[0].ts
  var last: number = first
  for ev in events
    if ev.ts < first
      first = ev.ts
    endif
    if ev.ts > last
      last = ev.ts
    endif
  endfor
  return [first, last]
enddef

# Bigrams are summed over the sessions separately, so no pair spans two of them.
def AllBigrams(events: list<dict<any>>): dict<number>
  var counts: dict<number> = {}
  for sequence in stats.KeySequences(events)
    for [gram, count] in items(stats.Ngrams(sequence, 2))
      counts[gram] = get(counts, gram, 0) + count
    endfor
  endfor
  return counts
enddef

# Commands grouped per session, in the order each session first appears. Two
# Vims running at once interleave their batches in the log, so a session is
# gathered wherever its events are.
def SessionCommands(events: list<dict<any>>): list<list<string>>
  var sessions: dict<list<dict<any>>> = {}
  var order: list<string> = []
  for ev in events
    if !has_key(sessions, ev.sid)
      sessions[ev.sid] = []
      add(order, ev.sid)
    endif
    add(sessions[ev.sid], ev)
  endfor
  return mapnew(order, (_, sid: string): list<string> => stats.GroupCommands(sessions[sid]))
enddef

# Advice is matched per session, so no run spans two of them. Rows that would
# save no keys are left out, and the rest are ranked by keys saved.
def Advice(sessions: list<list<string>>, limit: number): list<dict<any>>
  var totals: dict<dict<number>> = {}
  for commands in sessions
    for [id, tally] in items(advice.Match(commands, advice.Rules()))
      var total: dict<number> = get(totals, id, {runs: 0, saved: 0})
      total.runs += tally.runs
      total.saved += tally.saved
      totals[id] = total
    endfor
  endfor
  var rows: list<dict<any>> = []
  for rule in advice.Rules()
    if get(totals, rule.id, {saved: 0}).saved > 0
      add(rows, extend({tip: rule.tip, help: rule.help}, totals[rule.id]))
    endif
  endfor
  sort(rows, (a: dict<any>, b: dict<any>): number => b.saved - a.saved)
  return limit > 0 && limit < len(rows) ? rows[0 : limit - 1] : rows
enddef

# Commands repeated three or more times in a row that no rule has a tip for,
# ranked by presses, so a gap in the catalogue shows up in the report.
def Untipped(sessions: list<list<string>>, limit: number): list<list<any>>
  var presses: dict<number> = {}
  for commands in sessions
    for [command, tally] in items(advice.Uncovered(commands, advice.Rules()))
      presses[command] = get(presses, command, 0) + tally.presses
    endfor
  endfor
  return stats.Top(presses, limit)
enddef
