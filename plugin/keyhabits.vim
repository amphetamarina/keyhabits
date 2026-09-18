vim9script

if exists('g:loaded_keyhabits')
  finish
endif
g:loaded_keyhabits = 1

# The composition root: builds the object graph from config.Load() and defines
# the user commands. Nothing else knows which store or recorder is used.

import autoload 'keyhabits/config.vim'
import autoload 'keyhabits/infra/jsonl_store.vim'
import autoload 'keyhabits/app/recorder.vim' as rec
import autoload 'keyhabits/infra/capture.vim'

if !exists('##KeyInputPre') || !has('patch-9.1.0564')
  echomsg 'keyhabits: Vim 9.1.0564 or newer is required (KeyInputPre and v:event.typedchar)'
  finish
endif

var session: capture.Capture = null_object
var store: jsonl_store.JsonlStore = null_object

# Built on first use, so a vimrc that sets g: options after this plugin loads
# is still honoured. Configuration is read once, when the session is built.
def Session(): capture.Capture
  if session is null_object
    var settings: dict<any> = config.Load()
    store = jsonl_store.JsonlStore.new(settings.log_file)
    var recorder: rec.Recorder = rec.Recorder.new(store, settings.flush_threshold)
    session = capture.Capture.new(recorder, settings.record_text, settings.flush_interval)
  endif
  return session
enddef

def StartRecording()
  Session().Start()
enddef

def StopRecording()
  Session().Stop()
enddef

def ClearLog(bang: string)
  var running: capture.Capture = Session()
  if running.IsRunning()
    running.Stop()
  endif
  if bang != '!' && confirm('Delete the keyhabits log?', "&Yes\n&No", 2) != 1
    echomsg 'keyhabits: log kept'
    return
  endif
  store.Clear()
  echomsg $'keyhabits: cleared {store.path}'
enddef

def AutoStart()
  if config.Load().auto_start
    StartRecording()
  endif
enddef

command! KeyHabitsStart StartRecording()
command! KeyHabitsStop StopRecording()
command! -bang KeyHabitsClear ClearLog('<bang>')

augroup keyhabits_plugin
  autocmd!
  autocmd VimEnter * AutoStart()
augroup END


