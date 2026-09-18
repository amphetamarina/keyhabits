vim9script

# The Reporter use case: turn a list of events into the Report data structure
# that the report buffer renders. Every count comes from the domain stats.

import autoload 'keyhabits/domain/stats.vim'

export def Build(events: list<dict<any>>, options: dict<any>): dict<any>
  var kept: list<dict<any>> = Since(events, get(options, 'since', 0))
  var limit: number = get(options, 'limit', 0)
  return {
    total_keys: len(kept),
    sessions: Sessions(kept),
    time_span: TimeSpan(kept),
    top_keys: stats.Top(stats.CountKeys(kept), limit),
    top_commands: stats.Top(stats.CountCommands(kept), limit),
    top_bigrams: stats.Top(AllBigrams(kept), limit),
    modes: stats.Top(stats.CountModes(kept), 0),
    filetypes: stats.Top(stats.CountFiletypes(kept), 0),
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
