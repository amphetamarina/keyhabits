vim9script

# Specs for the append-only JSONL EventStore adapter.

import './spec.vim' as spec
import autoload 'keyhabits/app/store.vim'
import autoload 'keyhabits/domain/event.vim'
import autoload 'keyhabits/infra/jsonl_store.vim'

def Built(overrides: dict<any>): dict<any>
  var raw: dict<any> = extend({
    ts: 1700000000,
    sid: 's1',
    grp: 1,
    mode: 'n',
    key: 'j',
    typed: '',
    ft: 'vim',
  }, overrides)
  return event.New(raw)
enddef

def Cleanup(path: string)
  if filereadable(path)
    delete(path)
  endif
enddef

spec.Describe('JsonlStore', () => {
  spec.It('can be used through the EventStore port', () => {
    var path: string = tempname()
    try
      var port: store.EventStore = jsonl_store.JsonlStore.new(path)
      port.Append([Built({key: 'a'})])
      spec.Expect(port.ReadAll()).ToEqual([Built({key: 'a'})])
    finally
      Cleanup(path)
    endtry
  })

  spec.It('reads an empty list when the file does not exist', () => {
    var log: jsonl_store.JsonlStore = jsonl_store.JsonlStore.new(tempname())
    spec.Expect(log.ReadAll()).ToEqual([])
    spec.Expect(log.skipped).ToEqual(0)
  })

  spec.It('appends events and reads them back', () => {
    var path: string = tempname()
    try
      var log: jsonl_store.JsonlStore = jsonl_store.JsonlStore.new(path)
      log.Append([Built({key: 'a'}), Built({key: 'b'})])
      spec.Expect(log.ReadAll()).ToEqual([Built({key: 'a'}), Built({key: 'b'})])
    finally
      Cleanup(path)
    endtry
  })

  spec.It('appends to an existing file instead of overwriting it', () => {
    var path: string = tempname()
    try
      var log: jsonl_store.JsonlStore = jsonl_store.JsonlStore.new(path)
      log.Append([Built({key: 'a'})])
      log.Append([Built({key: 'b'})])
      var events: list<dict<any>> = log.ReadAll()
      spec.Expect(events).ToHaveLength(2)
      spec.Expect(events[0].key).ToEqual('a')
      spec.Expect(events[1].key).ToEqual('b')
    finally
      Cleanup(path)
    endtry
  })

  spec.It('does not create a file when there is nothing to append', () => {
    var path: string = tempname()
    var nothing: list<dict<any>> = []
    var log: jsonl_store.JsonlStore = jsonl_store.JsonlStore.new(path)
    log.Append(nothing)
    spec.Expect(filereadable(path)).ToBeFalse()
  })

  spec.It('creates the parent directory on the first append', () => {
    var dir: string = tempname()
    var path: string = dir .. '/nested/events.jsonl'
    try
      var log: jsonl_store.JsonlStore = jsonl_store.JsonlStore.new(path)
      log.Append([Built({key: 'a'})])
      spec.Expect(isdirectory(dir .. '/nested')).ToBeTrue()
      spec.Expect(log.ReadAll()).ToEqual([Built({key: 'a'})])
    finally
      delete(dir, 'rf')
    endtry
  })

  spec.It('skips a corrupt line, keeps the valid ones and counts the skip', () => {
    var path: string = tempname()
    try
      var lines: list<string> = [
        event.Encode(Built({key: 'a'})),
        'this is not json',
        event.Encode(Built({key: 'b'})),
      ]
      writefile(lines, path)
      var log: jsonl_store.JsonlStore = jsonl_store.JsonlStore.new(path)
      spec.Expect(log.ReadAll()).ToEqual([Built({key: 'a'}), Built({key: 'b'})])
      spec.Expect(log.skipped).ToEqual(1)
    finally
      Cleanup(path)
    endtry
  })

  spec.It('resets the skipped count on every read', () => {
    var path: string = tempname()
    try
      writefile(['this is not json'], path)
      var log: jsonl_store.JsonlStore = jsonl_store.JsonlStore.new(path)
      spec.Expect(log.ReadAll()).ToEqual([])
      spec.Expect(log.skipped).ToEqual(1)
      writefile([event.Encode(Built({key: 'a'}))], path)
      spec.Expect(log.ReadAll()).ToEqual([Built({key: 'a'})])
      spec.Expect(log.skipped).ToEqual(0)
    finally
      Cleanup(path)
    endtry
  })

  spec.It('clears the log', () => {
    var path: string = tempname()
    try
      var log: jsonl_store.JsonlStore = jsonl_store.JsonlStore.new(path)
      log.Append([Built({key: 'a'})])
      spec.Expect(filereadable(path)).ToBeTrue()
      log.Clear()
      spec.Expect(filereadable(path)).ToBeFalse()
      spec.Expect(log.ReadAll()).ToEqual([])
    finally
      Cleanup(path)
    endtry
  })

  spec.It('clears a missing log without complaining', () => {
    var log: jsonl_store.JsonlStore = jsonl_store.JsonlStore.new(tempname())
    log.Clear()
    spec.Expect(log.ReadAll()).ToEqual([])
  })
})
