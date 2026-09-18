vim9script

# Specs for the Recorder use case.

import './spec.vim' as spec
import autoload 'keyhabits/app/store.vim'
import autoload 'keyhabits/infra/memory_store.vim'
import autoload 'keyhabits/app/recorder.vim'

# Counts how often the store is touched, to prove that flushing an empty
# buffer never calls Append.
class SpyStore implements store.EventStore
  var appends: number = 0
  var stored: list<dict<any>> = []

  def Append(events: list<dict<any>>)
    this.appends += 1
    extend(this.stored, events)
  enddef

  def ReadAll(): list<dict<any>>
    return deepcopy(this.stored)
  enddef

  def Clear()
    this.stored = []
  enddef
endclass

def Ev(key: string): dict<any>
  return {
    ts: 1700000000,
    sid: 's1',
    grp: 1,
    mode: 'n',
    key: key,
    typed: '',
    ft: 'vim',
  }
enddef

spec.Describe('Recorder', () => {
  spec.It('buffers events below the threshold', () => {
    var memory: memory_store.MemoryStore = memory_store.MemoryStore.new()
    var subject: recorder.Recorder = recorder.Recorder.new(memory, 3)
    subject.Record(Ev('a'))
    subject.Record(Ev('b'))
    spec.Expect(subject.Pending()).ToEqual(2)
    spec.Expect(memory.ReadAll()).ToEqual([])
  })

  spec.It('stores everything in order once the threshold is reached', () => {
    var memory: memory_store.MemoryStore = memory_store.MemoryStore.new()
    var subject: recorder.Recorder = recorder.Recorder.new(memory, 3)
    subject.Record(Ev('a'))
    subject.Record(Ev('b'))
    subject.Record(Ev('c'))
    spec.Expect(subject.Pending()).ToEqual(0)
    spec.Expect(memory.ReadAll()).ToEqual([Ev('a'), Ev('b'), Ev('c')])
  })

  spec.It('does not duplicate events across flushes', () => {
    var memory: memory_store.MemoryStore = memory_store.MemoryStore.new()
    var subject: recorder.Recorder = recorder.Recorder.new(memory, 2)
    subject.Record(Ev('a'))
    subject.Record(Ev('b'))
    subject.Record(Ev('c'))
    subject.Record(Ev('d'))
    spec.Expect(memory.ReadAll()).ToEqual([Ev('a'), Ev('b'), Ev('c'), Ev('d')])
  })

  spec.It('stores a partial buffer on a manual flush', () => {
    var memory: memory_store.MemoryStore = memory_store.MemoryStore.new()
    var subject: recorder.Recorder = recorder.Recorder.new(memory, 5)
    subject.Record(Ev('a'))
    subject.Flush()
    spec.Expect(subject.Pending()).ToEqual(0)
    spec.Expect(memory.ReadAll()).ToEqual([Ev('a')])
  })

  spec.It('never calls Append for an empty buffer', () => {
    var spy: SpyStore = SpyStore.new()
    var subject: recorder.Recorder = recorder.Recorder.new(spy, 2)
    subject.Flush()
    spec.Expect(spy.appends).ToEqual(0)
    subject.Record(Ev('a'))
    subject.Record(Ev('b'))
    spec.Expect(spy.appends).ToEqual(1)
    subject.Flush()
    spec.Expect(spy.appends).ToEqual(1)
  })

  spec.It('stores every event immediately when the threshold is one', () => {
    var memory: memory_store.MemoryStore = memory_store.MemoryStore.new()
    var subject: recorder.Recorder = recorder.Recorder.new(memory, 1)
    subject.Record(Ev('a'))
    spec.Expect(subject.Pending()).ToEqual(0)
    spec.Expect(memory.ReadAll()).ToEqual([Ev('a')])
  })

  spec.It('rejects a threshold below one', () => {
    var memory: memory_store.MemoryStore = memory_store.MemoryStore.new()
    var message: string = 'keyhabits.recorder: flush_threshold must be at least 1'
    spec.Expect(() => recorder.Recorder.new(memory, 0)).ToThrow(message)
  })
})
