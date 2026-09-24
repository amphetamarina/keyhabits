vim9script

# Specs for live capture.
#
# Headless -es never leaves Ex mode: mode(1) reports 'ce' for keys typed
# outside an insert sequence and SafeState never fires, so these specs call
# NextGroup() directly and assert nothing about mode names. 'ce' belongs to the
# Command-line family, so printable keys typed in Ex mode are redacted as well.
# The trailing key is 'j' rather than 'x', because feeding 'x' headless makes
# Vim execute :xit and emit two key events of its own.

import './spec.vim' as spec
import autoload 'keyhabits/app/recorder.vim' as rec
import autoload 'keyhabits/infra/memory_store.vim'
import autoload 'keyhabits/infra/capture.vim'

# Starts a capture over a fresh store, opens a scratch buffer, runs Body, and
# always stops and wipes the buffer afterwards. Returns what the store got.
def Recorded(record_text: bool, flush_interval: number, Body: func(capture.Capture, memory_store.MemoryStore)): list<dict<any>>
  var store: memory_store.MemoryStore = memory_store.MemoryStore.new()
  var subject: capture.Capture = capture.Capture.new(rec.Recorder.new(store, 1000), record_text, flush_interval)
  var scratch: number = -1
  try
    subject.Start()
    enew
    scratch = bufnr('%')
    Body(subject, store)
  finally
    subject.Stop()
    Wipe(scratch)
  endtry
  return store.ReadAll()
enddef

# Statistics count the typed key, so these specs read typed as well.
def TypedNames(events: list<dict<any>>): list<string>
  var names: list<string> = []
  for ev in events
    add(names, ev.typed)
  endfor
  return names
enddef

def Wipe(buffer: number)
  if buffer > 0 && bufexists(buffer)
    execute 'bwipeout! ' .. buffer
  endif
enddef

spec.Describe('Capture', () => {
  spec.It('records keys with a session id and command groups', () => {
    var events: list<dict<any>> = Recorded(false, 0, (subject: capture.Capture, _: memory_store.MemoryStore) => {
      spec.Expect(subject.IsRunning()).ToBeTrue()
      feedkeys("ihi\<Esc>", 'xt')
      subject.NextGroup()
      feedkeys('j', 'xt')
    })
    spec.Expect(events).ToHaveLength(5)
    spec.Expect(TypedNames(events)).ToEqual(['<text>', '<text>', '<text>', '<Esc>', '<text>'])
    spec.Expect(events[0].grp).ToEqual(0)
    spec.Expect(events[3].grp).ToEqual(0)
    spec.Expect(events[4].grp).ToEqual(1)
    spec.Expect(events[0].sid).ToEqual(events[4].sid)
    spec.Expect(events[0].sid).NotToEqual('')
    for ev in events
      spec.Expect(ev.ts > 0).ToBeTrue()
    endfor
  })

  spec.It('keeps text when record_text is true', () => {
    var events: list<dict<any>> = Recorded(true, 0, (_: capture.Capture, _: memory_store.MemoryStore) => {
      feedkeys("ihi\<Esc>", 'xt')
    })
    spec.Expect(TypedNames(events)).ToEqual(['i', 'h', 'i', '<Esc>'])
  })

  spec.It('does not register twice when started twice', () => {
    var events: list<dict<any>> = Recorded(false, 0, (subject: capture.Capture, _: memory_store.MemoryStore) => {
      subject.Start()
      feedkeys('j', 'xt')
    })
    spec.Expect(events).ToHaveLength(1)
  })

  spec.It('flushes on the timer while recording', () => {
    var events: list<dict<any>> = Recorded(false, 20, (_: capture.Capture, store: memory_store.MemoryStore) => {
      feedkeys('j', 'xt')
      spec.Expect(store.ReadAll()).ToEqual([])
      sleep 60m
      spec.Expect(store.ReadAll()).ToHaveLength(1)
    })
    spec.Expect(events).ToHaveLength(1)
  })

  spec.It('records only keys the user typed', () => {
    var generated: list<dict<any>> = Recorded(false, 0, (_: capture.Capture, _: memory_store.MemoryStore) => {
      feedkeys('j', 'x')
    })
    spec.Expect(generated).ToEqual([])
  })

  spec.It('records nothing after Stop', () => {
    var store: memory_store.MemoryStore = memory_store.MemoryStore.new()
    var subject: capture.Capture = capture.Capture.new(rec.Recorder.new(store, 1000), false, 0)
    subject.Start()
    subject.Stop()
    feedkeys('j', 'xt')
    spec.Expect(subject.IsRunning()).ToBeFalse()
    spec.Expect(store.ReadAll()).ToEqual([])
  })
})

spec.Describe('capture command boundaries', () => {
  spec.It('ends a command only when the new mode is Normal proper', () => {
    spec.Expect(capture.IsCommandEnd('n')).ToBeTrue()
    spec.Expect(capture.IsCommandEnd('no')).ToBeFalse()
    spec.Expect(capture.IsCommandEnd('ce')).ToBeFalse()
    spec.Expect(capture.IsCommandEnd('i')).ToBeFalse()
    spec.Expect(capture.IsCommandEnd('niI')).ToBeFalse()
  })

  spec.It('treats SafeState as a boundary only in Normal modes', () => {
    spec.Expect(capture.IsSafeBoundary('n')).ToBeTrue()
    spec.Expect(capture.IsSafeBoundary('no')).ToBeTrue()
    spec.Expect(capture.IsSafeBoundary('i')).ToBeFalse()
    spec.Expect(capture.IsSafeBoundary('c')).ToBeFalse()
    spec.Expect(capture.IsSafeBoundary('v')).ToBeFalse()
    spec.Expect(capture.IsSafeBoundary('ce')).ToBeFalse()
    spec.Expect(capture.IsSafeBoundary('')).ToBeFalse()
  })
})

def KeyEvent(grp: number, mode: string, typed: string): dict<any>
  return {ts: 1700000000, sid: 's1', grp: grp, mode: mode, key: typed, typed: typed, ft: ''}
enddef

def Listening(heard: list<string>): capture.Capture
  var store: memory_store.MemoryStore = memory_store.MemoryStore.new()
  var subject: capture.Capture = capture.Capture.new(rec.Recorder.new(store, 1000), false, 0)
  subject.OnCommand((command: string) => {
    add(heard, command)
  })
  return subject
enddef

spec.Describe('capture command listener', () => {
  spec.It('hands each finished command to the listener', () => {
    var heard: list<string> = []
    var subject: capture.Capture = Listening(heard)
    subject.Take(KeyEvent(0, 'n', 'c'))
    subject.Take(KeyEvent(0, 'no', 'i'))
    subject.Take(KeyEvent(0, 'no', 'w'))
    subject.Take(KeyEvent(0, 'i', '<text>'))
    subject.Take(KeyEvent(0, 'i', '<Esc>'))
    subject.NextGroup()
    subject.Take(KeyEvent(1, 'n', 'j'))
    subject.NextGroup()
    spec.Expect(heard).ToEqual(['ciw<text><Esc>', 'j'])
  })

  spec.It('says nothing for a boundary without keys', () => {
    var heard: list<string> = []
    var subject: capture.Capture = Listening(heard)
    subject.NextGroup()
    subject.NextGroup()
    spec.Expect(heard).ToEqual([])
  })

  spec.It('says nothing for keys that are not a command', () => {
    var heard: list<string> = []
    var subject: capture.Capture = Listening(heard)
    subject.Take(KeyEvent(0, 'ce', '<text>'))
    subject.NextGroup()
    spec.Expect(heard).ToEqual([])
  })

  spec.It('still records every key it takes', () => {
    var store: memory_store.MemoryStore = memory_store.MemoryStore.new()
    var subject: capture.Capture = capture.Capture.new(rec.Recorder.new(store, 1), false, 0)
    subject.Take(KeyEvent(0, 'n', 'j'))
    subject.NextGroup()
    spec.Expect(store.ReadAll()).ToHaveLength(1)
  })
})
