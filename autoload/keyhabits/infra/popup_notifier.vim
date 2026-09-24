vim9script

# Shows a tip in a notification popup: top right, gone after a few seconds,
# never taking focus or keys. A new tip replaces one that is still showing.

import autoload 'keyhabits/app/notifier.vim' as port

const display_time: number = 4000

export def Lines(rule: dict<any>): list<string>
  return [$'keyhabits: {rule.tip}', $':help {rule.help}']
enddef

export class PopupNotifier implements port.Notifier
  var popup: number = 0

  def Notify(rule: dict<any>)
    if this.popup != 0
      popup_close(this.popup)
    endif
    this.popup = popup_notification(Lines(rule), {
      pos: 'topright',
      line: 1,
      col: &columns,
      time: display_time,
      highlight: 'Pmenu',
    })
  enddef

  def Current(): number
    return this.popup
  enddef
endclass
