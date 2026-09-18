vim9script

# Live capture: Vim's key, SafeState and exit events become recorded events.
# Buffering and batching belong to the Recorder; everything here is just the
# glue to Vim, so the hooks stay cheap and the instance stays reachable.

import autoload 'keyhabits/app/recorder.vim' as rec
import autoload 'keyhabits/domain/event.vim'

# A command ends when Vim returns to Normal proper; 'no' (operator-pending) is
# not the end of anything.
export def IsCommandEnd(new_mode: string): bool
  return new_mode == 'n'
enddef

# SafeState only separates plain Normal motions. In other modes it fires after
# every key and would fragment a command.
export def IsSafeBoundary(mode: string): bool
  return mode != '' && mode[0] == 'n'
enddef

export class Capture
  var recorder: rec.Recorder
  var record_text: bool
  var flush_interval: number
  var running: bool = false
  var session: string = ''
  var group: number = 0
  var timer: number = 0

  def new(this.recorder, this.record_text, this.flush_interval)
  enddef

  def Start()
    if this.running
      return
    endif
    this.session = getpid() .. '-' .. localtime()
    this.group = 0
    this.running = true
    active = this
    augroup keyhabits
      autocmd!
      autocmd KeyInputPre * OnKey()
      autocmd ModeChanged *:n* OnModeChanged()
      autocmd SafeState * OnSafeState()
      autocmd VimLeavePre * OnLeave()
    augroup END
    if this.flush_interval > 0
      this.timer = timer_start(this.flush_interval, OnFlushTimer, {repeat: -1})
    endif
  enddef

  def Stop()
    if !this.running
      return
    endif
    this.recorder.Flush()
    augroup keyhabits
      autocmd!
    augroup END
    if this.timer != 0
      timer_stop(this.timer)
      this.timer = 0
    endif
    this.running = false
    active = null_object
  enddef

  def IsRunning(): bool
    return this.running
  enddef

  def NextGroup()
    this.group += 1
  enddef

  def Flush()
    this.recorder.Flush()
  enddef
endclass

# The hooks reach the running instance through this variable, which has to be
# declared after the class.
var active: Capture = null_object

def OnKey()
  # Vim raises KeyInputPre again for keys it generates itself: 'x' runs as 'dl'
  # and a mapping replays its right-hand side. Those carry no typed character
  # and are not habits, so they are dropped here.
  if v:event.typedchar == ''
    return
  endif
  var raw: dict<any> = {
    ts: localtime(),
    sid: active.session,
    grp: active.group,
    mode: mode(1),
    key: v:char,
    typed: v:event.typedchar,
    ft: &filetype,
  }
  active.recorder.Record(event.New(raw, active.record_text))
enddef

def OnModeChanged()
  if IsCommandEnd(v:event.new_mode)
    active.NextGroup()
  endif
enddef

def OnSafeState()
  if IsSafeBoundary(mode(1))
    active.NextGroup()
  endif
enddef

def OnLeave()
  active.recorder.Flush()
enddef

def OnFlushTimer(_: number)
  if active is null_object
    return
  endif
  active.recorder.Flush()
enddef
