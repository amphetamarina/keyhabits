vim9script

if exists('g:loaded_keyhabits')
  finish
endif
g:loaded_keyhabits = 1

# The composition root: builds the object graph from config.Load() and defines
# the user commands. Nothing else knows which store or recorder is used.

import autoload 'keyhabits/config.vim'
import autoload 'keyhabits/app/reporter.vim'
import autoload 'keyhabits/infra/jsonl_store.vim'
import autoload 'keyhabits/infra/report_buffer.vim'
import autoload 'keyhabits/app/recorder.vim' as rec
import autoload 'keyhabits/infra/capture.vim'
import autoload 'keyhabits/app/coach.vim'
import autoload 'keyhabits/domain/advice.vim'
import autoload 'keyhabits/infra/popup_notifier.vim'

if !exists('##KeyInputPre') || !has('patch-9.1.0564')
  echomsg 'keyhabits: Vim 9.1.0564 or newer is required (KeyInputPre and v:event.typedchar)'
  finish
endif

var store: jsonl_store.JsonlStore = null_object
var session: capture.Capture = null_object

# The store and the session are built on first use, so a vimrc that sets g:
# options after this file is loaded is still honoured.
def Store(): jsonl_store.JsonlStore
  if store is null_object
    store = jsonl_store.JsonlStore.new(config.Load().log_file)
  endif
  return store
enddef

def Session(): capture.Capture
  if session is null_object
    var settings: dict<any> = config.Load()
    var recorder: rec.Recorder = rec.Recorder.new(Store(), settings.flush_threshold)
    session = capture.Capture.new(recorder, settings.record_text, settings.flush_interval)
    if settings.nudge
      session.OnCommand(Nudger(settings))
    endif
  endif
  return session
enddef

# Live tips. A macro being recorded or replayed is deliberate repetition, so
# its commands are not coached.
def Nudger(settings: dict<any>): func(string)
  var tips: coach.Coach = coach.Coach.new(
    popup_notifier.PopupNotifier.new(),
    advice.Rules(),
    settings.nudge_threshold,
    settings.nudge_window,
    settings.nudge_cooldown)
  return (command: string) => {
    if reg_recording() == '' && reg_executing() == ''
      tips.Observe(command, localtime())
    endif
  }
enddef

def StartRecording()
  Session().Start()
enddef

def StopRecording()
  Session().Stop()
enddef

def ClearLog(bang: string)
  var subject: capture.Capture = Session()
  if subject.IsRunning()
    subject.Stop()
  endif
  if bang != '!' && confirm('Delete the keyhabits log?', "&Yes\n&No", 2) != 1
    echomsg 'keyhabits: log kept'
    return
  endif
  Store().Clear()
  echomsg $'keyhabits: cleared {Store().path}'
enddef

def ShowReport(arg: string)
  var days: number = str2nr(arg)
  var since: number = days > 0 ? localtime() - days * 86400 : 0
  if session isnot null_object && session.IsRunning()
    session.Flush()
  endif
  var log: jsonl_store.JsonlStore = Store()
  var events: list<dict<any>> = log.ReadAll()
  if log.skipped > 0
    echomsg $'keyhabits: skipped {log.skipped} unreadable lines'
  endif
  var settings: dict<any> = config.Load()
  var report: dict<any> = reporter.Build(events, {limit: settings.report_limit, since: since})
  report_buffer.Open(report_buffer.Render(report))
enddef

def AutoStart()
  if config.Load().auto_start
    StartRecording()
  endif
enddef

command! KeyHabitsStart StartRecording()
command! KeyHabitsStop StopRecording()
command! -nargs=? KeyHabitsReport ShowReport(<q-args>)
command! -bang KeyHabitsClear ClearLog('<bang>')

augroup keyhabits_plugin
  autocmd!
  autocmd VimEnter * AutoStart()
augroup END
