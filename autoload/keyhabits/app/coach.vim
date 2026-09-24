vim9script

# The Coach use case: live nudges. It watches the commands of the last few
# seconds and, when one advice rule keeps matching, hands that rule to the
# notifier. Time comes in with every command, so nothing here reads a clock.

import autoload 'keyhabits/app/notifier.vim' as port
import autoload 'keyhabits/domain/advice.vim'

# Matching runs after every command, so the window is also capped in size to
# keep that cheap during a burst of motions.
const max_recent: number = 50

export class Coach
  var notifier: port.Notifier
  var rules: list<dict<any>>
  var threshold: number
  var window: number
  var cooldown: number
  var recent: list<list<any>> = []
  var shown_at: dict<number> = {}

  def new(this.notifier, this.rules, this.threshold, this.window, this.cooldown)
  enddef

  # Takes one finished command. Shows at most one tip: the first rule, in
  # catalogue order, that reached the threshold and is not cooling down.
  def Observe(command: string, now: number)
    add(this.recent, [now, command])
    this._Forget(now)
    var found: dict<dict<number>> = advice.Match(this._Commands(), this.rules)
    for rule in this.rules
      if this._IsDue(rule.id, get(found, rule.id, {runs: 0}).runs, now)
        this.shown_at[rule.id] = now
        this.notifier.Notify(rule)
        return
      endif
    endfor
  enddef

  def _IsDue(id: string, runs: number, now: number): bool
    if runs < this.threshold
      return false
    endif
    return !has_key(this.shown_at, id) || now - this.shown_at[id] >= this.cooldown
  enddef

  def _Forget(now: number)
    filter(this.recent, (_, entry: list<any>): bool => now - entry[0] < this.window)
    if len(this.recent) > max_recent
      this.recent = this.recent[-max_recent :]
    endif
  enddef

  def _Commands(): list<string>
    return mapnew(this.recent, (_, entry: list<any>): string => entry[1])
  enddef
endclass
