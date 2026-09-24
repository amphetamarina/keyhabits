vim9script

# Specs for the advice catalogue and matcher.

import './spec.vim' as spec
import autoload 'keyhabits/domain/advice.vim'

def RuleIds(): list<string>
  return mapnew(advice.Rules(), (_, rule: dict<any>): string => rule.id)
enddef

def Only(id: string): list<dict<any>>
  return filter(copy(advice.Rules()), (_, rule: dict<any>): bool => rule.id ==# id)
enddef

spec.Describe('advice.Rules', () => {
  spec.It('cites a help tag that exists for every rule', () => {
    var missing: list<string> = []
    for rule in advice.Rules()
      if index(getcompletion(rule.help, 'help'), rule.help) < 0
        add(missing, $'{rule.id}: {rule.help}')
      endif
    endfor
    spec.Expect(missing).ToEqual([])
  })

  spec.It('gives every rule a unique id', () => {
    var ids: list<string> = RuleIds()
    spec.Expect(len(uniq(sort(copy(ids))))).ToEqual(len(ids))
  })

  spec.It('states the keys saved in exactly one way for every rule', () => {
    var unclear: list<string> = []
    for rule in advice.Rules()
      if has_key(rule, 'fix') == has_key(rule, 'saves')
        add(unclear, rule.id)
      endif
    endfor
    spec.Expect(unclear).ToEqual([])
  })

  spec.It('matches its own example, before any other rule, and saves keys', () => {
    var broken: list<string> = []
    for rule in advice.Rules()
      var found: dict<dict<number>> = advice.Match(rule.example, advice.Rules())
      if keys(found) != [rule.id] || found[rule.id].runs != 1 || found[rule.id].saved < 1
        add(broken, $'{rule.id}: {string(found)}')
      endif
    endfor
    spec.Expect(broken).ToEqual([])
  })

  spec.It('gives every rule a tip, a sequence and a positive minimum', () => {
    var incomplete: list<string> = []
    for rule in advice.Rules()
      if rule.tip == '' || len(rule.sequence) == 0 || rule.min < 1
        add(incomplete, rule.id)
      endif
    endfor
    spec.Expect(incomplete).ToEqual([])
  })
})

spec.Describe('advice.KeyCount', () => {
  spec.It('counts plain keys one by one', () => {
    spec.Expect(advice.KeyCount('3dd')).ToEqual(3)
  })

  spec.It('counts a named key as one key', () => {
    spec.Expect(advice.KeyCount('<C-D>')).ToEqual(1)
    spec.Expect(advice.KeyCount('f<lt>')).ToEqual(2)
  })

  spec.It('leaves typed text out', () => {
    spec.Expect(advice.KeyCount('ciw<text><Esc>')).ToEqual(4)
  })
})

spec.Describe('advice.Match', () => {
  spec.It('finds nothing in no commands', () => {
    spec.Expect(advice.Match([], advice.Rules())).ToEqual({})
  })

  spec.It('counts a run of j as one run and the keys a count saves', () => {
    var commands: list<string> = ['j', 'j', 'j', 'j', 'j', 'j']
    spec.Expect(advice.Match(commands, advice.Rules())).ToEqual(
      {'repeated-j': {runs: 1, saved: 4}})
  })

  spec.It('ignores a run shorter than the minimum', () => {
    spec.Expect(advice.Match(['j', 'j', 'j'], advice.Rules())).ToEqual({})
  })

  spec.It('suggests a count for repeated word motions', () => {
    var commands: list<string> = ['w', 'w', 'w', 'w', 'j', 'b', 'b', 'b', 'b', 'b', 'e', 'e', 'e', 'e']
    spec.Expect(advice.Match(commands, advice.Rules())).ToEqual({
      'repeated-w': {runs: 1, saved: 2}, 'repeated-b': {runs: 1, saved: 3}, 'repeated-e': {runs: 1, saved: 2}})
  })

  spec.It('treats arrow keys like the motion they repeat', () => {
    var commands: list<string> = ['<Down>', 'j', '<Down>', 'j']
    spec.Expect(advice.Match(commands, advice.Rules())).ToEqual(
      {'repeated-j': {runs: 1, saved: 2}})
  })

  spec.It('counts separate runs separately', () => {
    var commands: list<string> = ['x', 'x', 'x', 'w', 'x', 'x', 'x', 'x']
    spec.Expect(advice.Match(commands, advice.Rules())).ToEqual(
      {'repeated-x': {runs: 2, saved: 3}})
  })

  spec.It('matches a sequence of two commands', () => {
    var commands: list<string> = ['$', 'a<text><Esc>']
    spec.Expect(advice.Match(commands, advice.Rules())).ToEqual(
      {'end-then-append': {runs: 1, saved: 1}})
  })

  spec.It('does not match a sequence that is interrupted', () => {
    var commands: list<string> = ['$', 'j', 'a<text><Esc>']
    spec.Expect(advice.Match(commands, advice.Rules())).ToEqual({})
  })

  spec.It('matches whole commands only', () => {
    spec.Expect(advice.Match(['5j', 'jj', 'd$x'], advice.Rules())).ToEqual({})
  })

  spec.It('matches a visual selection of a text object', () => {
    var commands: list<string> = ['viwd', 'va<lt>y', 'vi"c<text><Esc>']
    var expected: dict<any> = {'select-object-then-operate': {runs: 2, saved: 2}}
    expected['select-object-then-change'] = {runs: 1, saved: 1}
    spec.Expect(advice.Match(commands, advice.Rules())).ToEqual(expected)
  })

  spec.It('lets the first matching rule consume the run', () => {
    var commands: list<string> = ['x', 'x', 'x', 'i<text><Esc>']
    spec.Expect(advice.Match(commands, advice.Rules())).ToEqual(
      {'repeated-x': {runs: 1, saved: 1}})
  })

  spec.It('uses only the rules it is given', () => {
    var commands: list<string> = ['d$', 'j', 'j', 'j', 'j']
    spec.Expect(advice.Match(commands, Only('delete-to-end'))).ToEqual(
      {'delete-to-end': {runs: 1, saved: 1}})
  })
})

spec.Describe('advice.Match with the rule options', () => {
  spec.It('asks for the same command when a rule says same', () => {
    spec.Expect(advice.Match(['f(', 'f('], Only('repeated-find'))).ToEqual(
      {'repeated-find': {runs: 1, saved: 1}})
    spec.Expect(advice.Match(['f(', 'f)'], Only('repeated-find'))).ToEqual({})
  })

  spec.It('charges the better way for each repeat with fix_each', () => {
    spec.Expect(advice.Match(['ta', 'ta', 'ta', 'ta'], Only('repeated-find'))).ToEqual(
      {'repeated-find': {runs: 1, saved: 3}})
  })

  spec.It('counts every matching part inside one command', () => {
    var command: string = 'a<text><BS><BS><BS><BS><BS><text><BS><BS><BS><BS><BS><BS><Esc>'
    spec.Expect(advice.Match([command], Only('backspace-run'))).ToEqual(
      {'backspace-run': {runs: 2, saved: 9}})
  })

  spec.It('uses the fixed saving for a rule whose commands carry an Insert', () => {
    var commands: list<string> = ['$', 'a<text><BS><text><CR><text><Esc>']
    spec.Expect(advice.Match(commands, advice.Rules())).ToEqual(
      {'end-then-append': {runs: 1, saved: 1}})
  })

  spec.It('prefers a long run over the shorter habit it starts with', () => {
    spec.Expect(keys(advice.Match(repeat(['j'], 20), advice.Rules()))).ToEqual(['far-j'])
  })
})

spec.Describe('advice.Uncovered', () => {
  spec.It('lists a command repeated three or more times that no rule covers', () => {
    var commands: list<string> = [':<text><CR>', ':<text><CR>', ':<text><CR>', 'j']
    spec.Expect(advice.Uncovered(commands, advice.Rules())).ToEqual(
      {':<text><CR>': {runs: 1, presses: 3}})
  })

  spec.It('leaves out a command some rule covers, even in a short run', () => {
    spec.Expect(advice.Uncovered(['j', 'j', 'j', 'dw', 'dw', 'dw'], advice.Rules())).ToEqual({})
  })

  spec.It('leaves out a command repeated only twice', () => {
    spec.Expect(advice.Uncovered(['gp', 'gp', 'w'], advice.Rules())).ToEqual({})
  })

  spec.It('adds up separate runs of the same command', () => {
    var commands: list<string> = ['gp', 'gp', 'gp', 'w', 'gp', 'gp', 'gp', 'gp']
    spec.Expect(advice.Uncovered(commands, advice.Rules())).ToEqual(
      {gp: {runs: 2, presses: 7}})
  })
})
