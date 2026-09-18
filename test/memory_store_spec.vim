vim9script

# Specs for the in-memory EventStore adapter.

import './spec.vim' as spec
import autoload 'keyhabits/app/store.vim'
import autoload 'keyhabits/infra/memory_store.vim'

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

spec.Describe('MemoryStore', () => {
  spec.It('can be used through the EventStore port', () => {
    var port: store.EventStore = memory_store.MemoryStore.new()
    port.Append([Ev({key: 'a'})])
    spec.Expect(port.ReadAll()).ToEqual([Ev({key: 'a'})])
  })

  spec.It('appends events and reads them back in order', () => {
    var events: memory_store.MemoryStore = memory_store.MemoryStore.new()
    events.Append([Ev({key: 'a'})])
    events.Append([Ev({key: 'b'}), Ev({key: 'c'})])
    spec.Expect(events.ReadAll()).ToEqual([Ev({key: 'a'}), Ev({key: 'b'}), Ev({key: 'c'})])
  })

  spec.It('returns a deep copy so callers cannot mutate the store', () => {
    var events: memory_store.MemoryStore = memory_store.MemoryStore.new()
    events.Append([Ev({key: 'a'})])
    var first_read: list<dict<any>> = events.ReadAll()
    add(first_read, Ev({key: 'b'}))
    remove(first_read, 0)
    var second_read: list<dict<any>> = events.ReadAll()
    second_read[0].key = 'mutated'
    spec.Expect(events.ReadAll()).ToEqual([Ev({key: 'a'})])
  })

  spec.It('clears every event', () => {
    var events: memory_store.MemoryStore = memory_store.MemoryStore.new()
    events.Append([Ev({key: 'a'}), Ev({key: 'b'})])
    events.Clear()
    spec.Expect(events.ReadAll()).ToEqual([])
  })
})
