vim9script

# An EventStore kept in memory: used by tests and dry runs.

import autoload 'keyhabits/app/store.vim'

export class MemoryStore implements store.EventStore
  var _events: list<dict<any>> = []

  def Append(events: list<dict<any>>)
    extend(this._events, events)
  enddef

  def ReadAll(): list<dict<any>>
    return deepcopy(this._events)
  enddef

  def Clear()
    this._events = []
  enddef
endclass
