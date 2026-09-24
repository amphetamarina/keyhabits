vim9script

# Specs for the Reporter use case.

import './spec.vim' as spec
import autoload 'keyhabits/app/reporter.vim'

# typed defaults to the same key, so specs that do not care about the
# difference stay short; pass typed explicitly to describe a mapping.
def Ev(overrides: dict<any>): dict<any>
  var ev: dict<any> = extend({
    ts: 1700000000,
    sid: 's1',
    grp: 1,
    mode: 'n',
    key: 'j',
    typed: '',
    ft: 'vim',
  }, overrides)
  if !has_key(overrides, 'typed')
    ev.typed = ev.key
  endif
  return ev
enddef

def Options(overrides: dict<any>): dict<any>
  return extend({limit: 10, since: 0}, overrides)
enddef

spec.Describe('reporter.Build', () => {
  spec.It('reports zeros and empty lists for no events', () => {
    var report: dict<any> = reporter.Build([], Options({}))
    spec.Expect(report.total_keys).ToEqual(0)
    spec.Expect(report.sessions).ToEqual(0)
    spec.Expect(report.time_span).ToEqual([0, 0])
    spec.Expect(report.top_keys).ToEqual([])
    spec.Expect(report.top_commands).ToEqual([])
    spec.Expect(report.top_bigrams).ToEqual([])
    spec.Expect(report.modes).ToEqual([])
    spec.Expect(report.filetypes).ToEqual([])
    spec.Expect(report.advice).ToEqual([])
    spec.Expect(report.untipped).ToEqual([])
  })

  spec.It('counts totals, sessions, the time span and every section', () => {
    var events: list<dict<any>> = [
      Ev({ts: 100, sid: 'a', grp: 1, key: 'c'}),
      Ev({ts: 150, sid: 'a', grp: 1, key: 'i'}),
      Ev({ts: 200, sid: 'a', grp: 1, key: 'w'}),
      Ev({ts: 300, sid: 'b', grp: 2, key: 'k'}),
    ]
    var report: dict<any> = reporter.Build(events, Options({}))
    spec.Expect(report.total_keys).ToEqual(4)
    spec.Expect(report.sessions).ToEqual(2)
    spec.Expect(report.time_span).ToEqual([100, 300])
    spec.Expect(report.top_keys).ToEqual([['c', 1], ['i', 1], ['k', 1], ['w', 1]])
    spec.Expect(report.top_commands).ToEqual([['ciw', 1], ['k', 1]])
    spec.Expect(report.top_bigrams).ToEqual([['ci', 1], ['iw', 1]])
    spec.Expect(report.modes).ToEqual([['n', 4]])
    spec.Expect(report.filetypes).ToEqual([['vim', 4]])
  })

  spec.It('drops events older than since and adjusts the totals', () => {
    var events: list<dict<any>> = [
      Ev({ts: 100, sid: 'a', key: 'j'}),
      Ev({ts: 200, sid: 'a', key: 'k'}),
      Ev({ts: 300, sid: 'b', key: 'k'}),
    ]
    var report: dict<any> = reporter.Build(events, Options({since: 250}))
    spec.Expect(report.total_keys).ToEqual(1)
    spec.Expect(report.sessions).ToEqual(1)
    spec.Expect(report.time_span).ToEqual([300, 300])
    spec.Expect(report.top_keys).ToEqual([['k', 1]])
  })

  spec.It('truncates keys and commands to the limit but keeps all modes', () => {
    var events: list<dict<any>> = [
      Ev({grp: 1, mode: 'n', key: 'a'}),
      Ev({grp: 2, mode: 'n', key: 'b'}),
      Ev({grp: 3, mode: 'n', key: 'c'}),
      Ev({grp: 4, mode: 'v', key: 'd'}),
    ]
    var report: dict<any> = reporter.Build(events, Options({limit: 1}))
    spec.Expect(report.top_keys).ToEqual([['a', 1]])
    spec.Expect(report.top_commands).ToEqual([['a', 1]])
    spec.Expect(report.modes).ToEqual([['n', 3], ['v', 1]])
  })

  spec.It('does not build key pairs across sessions', () => {
    var events: list<dict<any>> = [
      Ev({sid: 's1', key: 'a'}),
      Ev({sid: 's1', key: 'b'}),
      Ev({sid: 's2', key: 'b'}),
      Ev({sid: 's2', key: 'c'}),
    ]
    var report: dict<any> = reporter.Build(events, Options({}))
    spec.Expect(report.top_bigrams).ToEqual([['ab', 1], ['bc', 1]])
  })

  spec.It('adds up a pair that repeats in another session', () => {
    var events: list<dict<any>> = [
      Ev({sid: 's1', key: 'a'}),
      Ev({sid: 's1', key: 'b'}),
      Ev({sid: 's2', key: 'a'}),
      Ev({sid: 's2', key: 'b'}),
    ]
    var report: dict<any> = reporter.Build(events, Options({}))
    spec.Expect(report.top_bigrams).ToEqual([['ab', 2]])
  })

  spec.It('turns a run of repeated motions into advice with its source', () => {
    var events: list<dict<any>> = mapnew(range(1, 6), (_, grp: number): dict<any> => Ev({grp: grp, key: 'j'}))
    var report: dict<any> = reporter.Build(events, Options({}))
    var tip: string = 'Give the motion a count instead of repeating j: 5j'
    spec.Expect(report.advice).ToEqual([{tip: tip, help: 'count', runs: 1, saved: 4}])
  })

  spec.It('does not match a run across sessions', () => {
    var events: list<dict<any>> = [
      Ev({sid: 's1', grp: 1, key: 'j'}),
      Ev({sid: 's1', grp: 2, key: 'j'}),
      Ev({sid: 's2', grp: 1, key: 'j'}),
      Ev({sid: 's2', grp: 2, key: 'j'}),
    ]
    spec.Expect(reporter.Build(events, Options({})).advice).ToEqual([])
  })

  spec.It('gathers a session whose events are interleaved with another', () => {
    var events: list<dict<any>> = [
      Ev({sid: 's1', grp: 1, key: 'j'}),
      Ev({sid: 's1', grp: 2, key: 'j'}),
      Ev({sid: 's2', grp: 1, key: 'k'}),
      Ev({sid: 's1', grp: 3, key: 'j'}),
      Ev({sid: 's1', grp: 4, key: 'j'}),
    ]
    var rows: list<dict<any>> = reporter.Build(events, Options({})).advice
    spec.Expect(mapnew(rows, (_, row: dict<any>): string => row.help)).ToEqual(['count'])
  })

  spec.It('ranks advice by keys saved and truncates it to the limit', () => {
    var events: list<dict<any>> = [
      Ev({grp: 1, key: 'd'}),
      Ev({grp: 1, key: '$'}),
      Ev({grp: 2, key: 'x'}),
      Ev({grp: 3, key: 'x'}),
      Ev({grp: 4, key: 'x'}),
      Ev({grp: 5, key: 'x'}),
      Ev({grp: 6, key: 'x'}),
    ]
    var rows: list<dict<any>> = reporter.Build(events, Options({limit: 1})).advice
    spec.Expect(mapnew(rows, (_, row: dict<any>): list<number> => [row.runs, row.saved])).ToEqual([[1, 3]])
    spec.Expect(rows[0].help).ToEqual('04.1')
  })

  spec.It('lists a repeated command that has no tip yet, per session', () => {
    var events: list<dict<any>> = [
      Ev({sid: 's1', grp: 1, key: 'g'}),
      Ev({sid: 's1', grp: 1, key: 'p'}),
      Ev({sid: 's1', grp: 2, key: 'g'}),
      Ev({sid: 's1', grp: 2, key: 'p'}),
      Ev({sid: 's2', grp: 1, key: 'g'}),
      Ev({sid: 's2', grp: 1, key: 'p'}),
      Ev({sid: 's3', grp: 1, key: 'g'}),
      Ev({sid: 's3', grp: 1, key: 'p'}),
      Ev({sid: 's3', grp: 2, key: 'g'}),
      Ev({sid: 's3', grp: 2, key: 'p'}),
      Ev({sid: 's3', grp: 3, key: 'g'}),
      Ev({sid: 's3', grp: 3, key: 'p'}),
    ]
    spec.Expect(reporter.Build(events, Options({})).untipped).ToEqual([['gp', 3]])
  })
})
