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
