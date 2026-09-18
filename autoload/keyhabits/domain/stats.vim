vim9script

# Pure statistics over lists of Events. Nothing here touches files, autocmds,
# timers or options: events in, plain data out.

const none_label: string = '[none]'

def CountNames(names: list<string>): dict<number>
  var counts: dict<number> = {}
  for name in names
    counts[name] = get(counts, name, 0) + 1
  endfor
  return counts
enddef

def NamesOf(events: list<dict<any>>, field: string): list<string>
  var names: list<string> = []
  for ev in events
    var name: string = ev[field]
    add(names, name)
  endfor
  return names
enddef

# Events belong to the same command when session and group number match.
def SameGroup(a: dict<any>, b: dict<any>): bool
  return a.sid ==# b.sid && a.grp == b.grp
enddef

# A command is started in Normal mode or in the Visual family (v, V, <C-V>).
def IsCommandMode(mode: string): bool
  return mode == "\<C-V>" || (mode != '' && stridx('nvV', mode[0]) >= 0)
enddef

export def CountKeys(events: list<dict<any>>): dict<number>
  return CountNames(NamesOf(events, 'key'))
enddef

export def CountModes(events: list<dict<any>>): dict<number>
  return CountNames(NamesOf(events, 'mode'))
enddef

export def CountFiletypes(events: list<dict<any>>): dict<number>
  var names: list<string> = map(
    NamesOf(events, 'ft'),
    (_, ft: string): string => ft == '' ? none_label : ft)
  return CountNames(names)
enddef

export def GroupCommands(events: list<dict<any>>): list<string>
  var commands: list<string> = []
  var index: number = 0
  while index < len(events)
    var first: dict<any> = events[index]
    var names: list<string> = []
    while index < len(events) && SameGroup(events[index], first)
      add(names, events[index].key)
      index += 1
    endwhile
    if IsCommandMode(first.mode)
      add(commands, join(names, ''))
    endif
  endwhile
  return commands
enddef

export def CountCommands(events: list<dict<any>>): dict<number>
  return CountNames(GroupCommands(events))
enddef

export def Ngrams(keys: list<string>, n: number): dict<number>
  if n < 1
    throw 'keyhabits.stats: n must be at least 1'
  endif
  if len(keys) < n
    return {}
  endif
  var counts: dict<number> = {}
  for start in range(len(keys) - n + 1)
    var gram: string = join(keys[start : start + n - 1], '')
    counts[gram] = get(counts, gram, 0) + 1
  endfor
  return counts
enddef

export def KeySequences(events: list<dict<any>>): list<list<string>>
  var sequences: list<list<string>> = []
  var session: string = ''
  for ev in events
    if len(sequences) == 0 || ev.sid !=# session
      add(sequences, [])
      session = ev.sid
    endif
    add(sequences[-1], ev.key)
  endfor
  return sequences
enddef

export def Top(counts: dict<number>, limit: number): list<list<any>>
  var pairs: list<list<any>> = []
  for [name, count] in items(counts)
    add(pairs, [name, count])
  endfor
  sort(pairs, (a: list<any>, b: list<any>): number => {
    if a[1] != b[1]
      return b[1] - a[1]
    endif
    return a[0] ==# b[0] ? 0 : a[0] <# b[0] ? -1 : 1
  })
  return limit > 0 && limit < len(pairs) ? pairs[0 : limit - 1] : pairs
enddef
