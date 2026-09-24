vim9script

# Specs for the popup notifier. Popups are created headless as well, so these
# specs check the real popup and close it afterwards.

import './spec.vim' as spec
import autoload 'keyhabits/infra/popup_notifier.vim'

const rule: dict<any> = {id: 'repeated-j', tip: 'Use 5j', help: 'count'}

def PopupLines(popup: number): list<string>
  return getbufline(winbufnr(popup), 1, '$')
enddef

spec.Describe('popup_notifier.Lines', () => {
  spec.It('shows the tip and the help command for its source', () => {
    spec.Expect(popup_notifier.Lines(rule)).ToEqual(['keyhabits: Use 5j', ':help count'])
  })
})

spec.Describe('popup_notifier.PopupNotifier', () => {
  spec.It('opens a notification in the top right that closes by itself', () => {
    var subject: popup_notifier.PopupNotifier = popup_notifier.PopupNotifier.new()
    try
      subject.Notify(rule)
      var options: dict<any> = popup_getoptions(subject.Current())
      spec.Expect(PopupLines(subject.Current())).ToEqual(popup_notifier.Lines(rule))
      spec.Expect(options.pos).ToEqual('topright')
      spec.Expect(options.time > 0).ToBeTrue()
    finally
      popup_clear()
    endtry
  })

  spec.It('replaces a tip that is still showing', () => {
    var subject: popup_notifier.PopupNotifier = popup_notifier.PopupNotifier.new()
    try
      subject.Notify(rule)
      var first: number = subject.Current()
      subject.Notify({id: 'repeated-k', tip: 'Use 5k', help: 'count'})
      spec.Expect(popup_getpos(first)).ToEqual({})
      spec.Expect(PopupLines(subject.Current())).ToEqual(['keyhabits: Use 5k', ':help count'])
    finally
      popup_clear()
    endtry
  })
})
