vim9script

# The Recorder use case: buffer key events in memory and hand them to the
# store in batches, so recording stays cheap. It knows nothing about autocmds,
# timers or files: the store and the threshold are passed in.

import autoload 'keyhabits/app/store.vim' as port

export class Recorder
  var store: port.EventStore
  var flush_threshold: number
  var _buffer: list<dict<any>> = []

  def new(this.store, this.flush_threshold)
    if this.flush_threshold < 1
      throw 'keyhabits.recorder: flush_threshold must be at least 1'
    endif
  enddef

  def Record(event: dict<any>)
    add(this._buffer, event)
    if len(this._buffer) >= this.flush_threshold
      this.Flush()
    endif
  enddef

  def Flush()
    if len(this._buffer) == 0
      return
    endif
    this.store.Append(this._buffer)
    this._buffer = []
  enddef

  def Pending(): number
    return len(this._buffer)
  enddef
endclass
