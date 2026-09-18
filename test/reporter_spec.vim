vim9script

# Specs for the Reporter use case.

import './spec.vim' as spec
import autoload 'keyhabits/app/reporter.vim'

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
})
