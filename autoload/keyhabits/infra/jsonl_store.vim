vim9script

# An EventStore backed by an append-only JSONL file: one event per line.
# Corrupt lines are skipped and counted in "skipped", which is reset on every
# ReadAll, so one bad line can never make the history unreadable.

import autoload 'keyhabits/app/store.vim'
import autoload 'keyhabits/domain/event.vim'

export class JsonlStore implements store.EventStore
  var path: string
  var skipped: number = 0

  def new(this.path)
  enddef

  def Append(events: list<dict<any>>)
    if len(events) == 0
      return
    endif
    this._EnsureDirectory()
    var lines: list<string> = []
    for ev in events
      add(lines, event.Encode(ev))
    endfor
    writefile(lines, this.path, 'a')
  enddef

  def ReadAll(): list<dict<any>>
    this.skipped = 0
    if !filereadable(this.path)
      return []
    endif
    var events: list<dict<any>> = []
    for line in readfile(this.path)
      try
        add(events, event.Decode(line))
      catch
        this.skipped += 1
      endtry
    endfor
    return events
  enddef

  def Clear()
    if filereadable(this.path)
      delete(this.path)
    endif
  enddef

  def _EnsureDirectory()
    var dir: string = fnamemodify(this.path, ':h')
    if dir != '' && !isdirectory(dir)
      mkdir(dir, 'p')
    endif
  enddef
endclass
