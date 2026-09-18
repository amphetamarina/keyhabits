vim9script

# Specs for the pure statistics over event lists.

import './spec.vim' as spec
import autoload 'keyhabits/domain/stats.vim'

def Ev(overrides: dict<any>): dict<any>
  return extend({
    ts: 1700000000,
    sid: 's1',
    grp: 1,
    mode: 'n',
    key: 'j',
    typed: '',
    ft: 'vim',
  }, overrides)
enddef

spec.Describe('stats with no events', () => {
  spec.It('returns empty results from every aggregation', () => {
    var events: list<dict<any>> = []
    spec.Expect(stats.CountKeys(events)).ToEqual({})
    spec.Expect(stats.CountModes(events)).ToEqual({})
    spec.Expect(stats.CountFiletypes(events)).ToEqual({})
    spec.Expect(stats.GroupCommands(events)).ToEqual([])
    spec.Expect(stats.CountCommands(events)).ToEqual({})
    spec.Expect(stats.KeySequences(events)).ToEqual([])
  })
})

spec.Describe('stats.CountKeys', () => {
  spec.It('counts every key name, including special keys', () => {
    var events: list<dict<any>> = [
      Ev({key: 'j'}),
      Ev({key: 'j'}),
      Ev({key: 'k'}),
      Ev({key: '<Esc>'}),
    ]
    spec.Expect(stats.CountKeys(events)).ToEqual({j: 2, k: 1, '<Esc>': 1})
  })
})

spec.Describe('stats.CountModes', () => {
  spec.It('counts every mode', () => {
    var events: list<dict<any>> = [
      Ev({mode: 'n'}),
      Ev({mode: 'i'}),
      Ev({mode: 'n'}),
    ]
    spec.Expect(stats.CountModes(events)).ToEqual({n: 2, i: 1})
  })
})

spec.Describe('stats.CountFiletypes', () => {
  spec.It('counts filetypes and groups an empty one under [none]', () => {
    var events: list<dict<any>> = [
      Ev({ft: 'vim'}),
      Ev({ft: ''}),
      Ev({ft: 'vim'}),
    ]
    spec.Expect(stats.CountFiletypes(events)).ToEqual({vim: 2, '[none]': 1})
  })
})

spec.Describe('stats.GroupCommands', () => {
  spec.It('joins the keys of one command', () => {
    var events: list<dict<any>> = [
      Ev({key: 'c'}),
      Ev({key: 'i'}),
      Ev({key: 'w'}),
    ]
    spec.Expect(stats.GroupCommands(events)).ToEqual(['ciw'])
  })

  spec.It('joins repeated keys and typed text', () => {
    var events: list<dict<any>> = [
      Ev({key: '3'}),
      Ev({key: 'd'}),
      Ev({key: 'd'}),
    ]
    spec.Expect(stats.GroupCommands(events)).ToEqual(['3dd'])

    var insert: list<dict<any>> = [
      Ev({key: 'i'}),
      Ev({mode: 'i', key: '<text>'}),
      Ev({mode: 'i', key: '<text>'}),
      Ev({mode: 'i', key: '<Esc>'}),
    ]
    spec.Expect(stats.GroupCommands(insert)).ToEqual(['i<text><text><Esc>'])
  })

  spec.It('drops a group that starts in insert mode', () => {
    var events: list<dict<any>> = [
      Ev({mode: 'i', key: 'a'}),
      Ev({mode: 'i', key: 'b'}),
    ]
    spec.Expect(stats.GroupCommands(events)).ToEqual([])
  })

  spec.It('keeps a group that starts in the visual family', () => {
    for mode in ['v', 'V', "\<C-V>"]
      var events: list<dict<any>> = [
        Ev({mode: mode, key: 'd'}),
        Ev({mode: mode, key: 'w'}),
      ]
      spec.Expect(stats.GroupCommands(events)).ToEqual(['dw'])
    endfor
  })

  spec.It('starts a new group when the group number changes', () => {
    var events: list<dict<any>> = [
      Ev({grp: 1, key: 'c'}),
      Ev({grp: 1, key: 'i'}),
      Ev({grp: 1, key: 'w'}),
      Ev({grp: 2, key: 'd'}),
      Ev({grp: 2, key: 'd'}),
    ]
    spec.Expect(stats.GroupCommands(events)).ToEqual(['ciw', 'dd'])
  })

  spec.It('starts a new group when the session changes', () => {
    var events: list<dict<any>> = [
      Ev({sid: 's1', grp: 1, key: 'c'}),
      Ev({sid: 's1', grp: 1, key: 'i'}),
      Ev({sid: 's1', grp: 1, key: 'w'}),
      Ev({sid: 's2', grp: 1, key: 'd'}),
      Ev({sid: 's2', grp: 1, key: 'd'}),
    ]
    spec.Expect(stats.GroupCommands(events)).ToEqual(['ciw', 'dd'])
  })
})

spec.Describe('stats.CountCommands', () => {
  spec.It('counts kept groups and ignores dropped ones', () => {
    var events: list<dict<any>> = [
      Ev({grp: 1, key: 'c'}),
      Ev({grp: 1, key: 'i'}),
      Ev({grp: 1, key: 'w'}),
      Ev({grp: 2, key: '3'}),
      Ev({grp: 2, key: 'd'}),
      Ev({grp: 2, key: 'd'}),
      Ev({grp: 3, mode: 'i', key: 'x'}),
    ]
    spec.Expect(stats.CountCommands(events)).ToEqual({'ciw': 1, '3dd': 1})
  })
})

spec.Describe('stats.Ngrams', () => {
  spec.It('counts sliding windows of one, two and three keys', () => {
    var key_names: list<string> = ['a', 'b', 'c']
    spec.Expect(stats.Ngrams(key_names, 1)).ToEqual({a: 1, b: 1, c: 1})
    spec.Expect(stats.Ngrams(key_names, 2)).ToEqual({ab: 1, bc: 1})
    spec.Expect(stats.Ngrams(key_names, 3)).ToEqual({abc: 1})
  })

  spec.It('counts a repeated window more than once', () => {
    spec.Expect(stats.Ngrams(['a', 'b', 'a', 'b'], 2)).ToEqual({ab: 2, ba: 1})
  })

  spec.It('returns an empty dict when there are fewer keys than the window', () => {
    spec.Expect(stats.Ngrams(['a'], 2)).ToEqual({})
    spec.Expect(stats.Ngrams([], 2)).ToEqual({})
  })

  spec.It('rejects a window smaller than one', () => {
    var key_names: list<string> = ['a', 'b']
    var message: string = 'keyhabits.stats: n must be at least 1'
    for n in [0, -1]
      spec.Expect(() => stats.Ngrams(key_names, n)).ToThrow(message)
    endfor
  })
})

spec.Describe('stats.KeySequences', () => {
  spec.It('returns one list per session, in order', () => {
    var events: list<dict<any>> = [
      Ev({sid: 's1', key: 'a'}),
      Ev({sid: 's1', key: 'b'}),
      Ev({sid: 's2', key: 'c'}),
      Ev({sid: 's1', key: 'd'}),
    ]
    spec.Expect(stats.KeySequences(events)).ToEqual([['a', 'b'], ['c'], ['d']])
  })

  spec.It('returns one list for a single session', () => {
    var events: list<dict<any>> = [Ev({key: 'a'}), Ev({key: 'b'})]
    spec.Expect(stats.KeySequences(events)).ToEqual([['a', 'b']])
  })
})

spec.Describe('stats.Top', () => {
  spec.It('sorts by count descending, then by key in byte order', () => {
    spec.Expect(stats.Top({a: 2, b: 5, c: 2}, 2)).ToEqual([['b', 5], ['a', 2]])
    spec.Expect(stats.Top({a: 1, B: 1}, 0)).ToEqual([['B', 1], ['a', 1]])
  })

  spec.It('truncates to the limit', () => {
    spec.Expect(stats.Top({a: 1, b: 2, c: 3}, 2)).ToEqual([['c', 3], ['b', 2]])
  })

  spec.It('returns everything when the limit is not positive', () => {
    spec.Expect(stats.Top({a: 1, b: 2}, 0)).ToEqual([['b', 2], ['a', 1]])
    spec.Expect(stats.Top({a: 1, b: 2}, -1)).ToEqual([['b', 2], ['a', 1]])
  })

  spec.It('returns an empty list when there is nothing to rank', () => {
    spec.Expect(stats.Top({}, 5)).ToEqual([])
  })
})
