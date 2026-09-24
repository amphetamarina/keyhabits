vim9script

# The advice catalogue and a pure matcher over lists of commands.
#
# Every tip comes from Vim's own help and names the tag it comes from, so the
# user can read the source with :help. A rule matches a run of consecutive
# commands, because SafeState ends a command after every plain motion: "jjjj"
# arrives as four "j" commands.

import autoload 'keyhabits/domain/event.vim'

# Fields of a rule:
#   id        stable name
#   sequence  regexes, each matched against one whole command, in order
#   min       how many times in a row the sequence must occur; a run of a
#             rule with min 1 is a single occurrence
#   fix       keys the better way takes, typed text not counted
#   tip       the better way, one line
#   help      the :help tag the tip comes from
const rules: list<dict<any>> = [
  {
    id: 'repeated-j',
    sequence: ['^\%(j\|<Down>\)$'],
    min: 4,
    fix: 2,
    tip: 'Give the motion a count instead of repeating j: 5j',
    help: 'count',
  },
  {
    id: 'repeated-k',
    sequence: ['^\%(k\|<Up>\)$'],
    min: 4,
    fix: 2,
    tip: 'Give the motion a count instead of repeating k: 5k',
    help: 'count',
  },
  {
    id: 'repeated-l',
    sequence: ['^\%(l\|<Right>\)$'],
    min: 4,
    fix: 2,
    tip: 'Move by words with w or e instead of repeating l',
    help: 'word-motions',
  },
  {
    id: 'repeated-h',
    sequence: ['^\%(h\|<Left>\)$'],
    min: 4,
    fix: 2,
    tip: 'Move back by words with b instead of repeating h',
    help: 'word-motions',
  },
  {
    id: 'repeated-x',
    sequence: ['^x$'],
    min: 3,
    fix: 2,
    tip: 'Delete with a count or a motion instead of repeating x: 4x, dw',
    help: '04.1',
  },
  {
    id: 'repeated-dd',
    sequence: ['^dd$'],
    min: 3,
    fix: 3,
    tip: 'Give dd a count instead of repeating it: 3dd',
    help: 'dd',
  },
  {
    id: 'end-then-append',
    sequence: ['^\$$', '^a\%(<text>\)\=<Esc>$'],
    min: 1,
    fix: 2,
    tip: 'Append at the end of the line with A instead of $a',
    help: 'A',
  },
  {
    id: 'first-then-insert',
    sequence: ['^\^$', '^i\%(<text>\)\=<Esc>$'],
    min: 1,
    fix: 2,
    tip: 'Insert before the first non-blank with I instead of ^i',
    help: 'I',
  },
  {
    id: 'x-then-insert',
    sequence: ['^x$', '^i\%(<text>\)\=<Esc>$'],
    min: 1,
    fix: 2,
    tip: 'Replace a character and start inserting with s instead of xi',
    help: 's',
  },
  {
    id: 'delete-to-end',
    sequence: ['^d\$$'],
    min: 1,
    fix: 1,
    tip: 'Delete to the end of the line with D instead of d$',
    help: 'D',
  },
  {
    id: 'change-to-end',
    sequence: ['^c\$\%(<text>\)\=<Esc>$'],
    min: 1,
    fix: 2,
    tip: 'Change to the end of the line with C instead of c$',
    help: 'C',
  },
  {
    id: 'select-object-then-operate',
    sequence: ['^v[ia]\%([wWsp()b{}B"''`t\[\]>]\|<lt>\)[dy]$'],
    min: 1,
    fix: 3,
    tip: 'Apply the operator to the text object directly: diw, ya"',
    help: '04.8',
  },
  {
    id: 'select-object-then-change',
    sequence: ['^v[ia]\%([wWsp()b{}B"''`t\[\]>]\|<lt>\)c\%(<text>\)\=<Esc>$'],
    min: 1,
    fix: 4,
    tip: 'Change the text object directly: ciw, ci"',
    help: '04.8',
  },
]

export def Rules(): list<dict<any>>
  return rules
enddef

# Keys typed for a command. Typed text is left out: it is the same whichever
# way the command is written.
export def KeyCount(command: string): number
  var without_text: string = substitute(command, event.PLACEHOLDER, '', 'g')
  return strcharlen(substitute(without_text, '<[^<>]\+>', '.', 'g'))
enddef

# How many commands a run of the rule consumes at start, or 0 if the rule does
# not match there.
def RunLength(commands: list<string>, start: number, rule: dict<any>): number
  var sequence: list<string> = rule.sequence
  var index: number = start
  var repeats: number = 0
  while SequenceAt(commands, index, sequence) && (repeats == 0 || rule.min > 1)
    index += len(sequence)
    repeats += 1
  endwhile
  return repeats >= rule.min ? index - start : 0
enddef

def SequenceAt(commands: list<string>, start: number, sequence: list<string>): bool
  if start + len(sequence) > len(commands)
    return false
  endif
  for offset in range(len(sequence))
    if commands[start + offset] !~# sequence[offset]
      return false
    endif
  endfor
  return true
enddef

def RunKeys(commands: list<string>): number
  var total: number = 0
  for command in commands
    total += KeyCount(command)
  endfor
  return total
enddef

# Scans the commands once. At each position the first rule that matches wins
# and its run is consumed, so a run is counted once. Returns, per rule id, the
# number of runs and the keys the better way would have saved.
export def Match(commands: list<string>, candidates: list<dict<any>>): dict<dict<number>>
  var found: dict<dict<number>> = {}
  var index: number = 0
  while index < len(commands)
    var consumed: number = 0
    for rule in candidates
      consumed = RunLength(commands, index, rule)
      if consumed > 0
        var run: list<string> = commands[index : index + consumed - 1]
        var tally: dict<number> = get(found, rule.id, {runs: 0, saved: 0})
        tally.runs += 1
        tally.saved += max([0, RunKeys(run) - rule.fix])
        found[rule.id] = tally
        break
      endif
    endfor
    index += consumed > 0 ? consumed : 1
  endwhile
  return found
enddef
