vim9script

# Specs for the plugin entry point: sourcing it defines the commands and wires
# them to the real JSONL store.
#
# The fed key is 'j' rather than 'x', because headless Ex mode would treat 'x'
# as :xit and emit extra key events of its own.

import './spec.vim' as spec

const root: string = fnamemodify(expand('<sfile>:p'), ':h:h')

spec.Describe('plugin/keyhabits.vim', () => {
  spec.It('defines the commands and records through them', () => {
    var log: string = tempname()
    g:keyhabits_auto_start = 0
    g:keyhabits_log_file = log
    try
      execute 'source ' .. root .. '/plugin/keyhabits.vim'
      spec.Expect(exists(':KeyHabitsStart')).ToEqual(2)
      spec.Expect(exists(':KeyHabitsStop')).ToEqual(2)
      spec.Expect(exists(':KeyHabitsClear')).ToEqual(2)
      spec.Expect(exists(':KeyHabitsReport')).ToEqual(0)

      execute 'KeyHabitsStart'
      feedkeys('j', 'xt')
      execute 'KeyHabitsStop'

      spec.Expect(filereadable(log)).ToBeTrue()
      spec.Expect(readfile(log)).ToHaveLength(1)
      spec.Expect(exists(':KeyHabitsStart')).ToEqual(2)

      execute 'KeyHabitsClear!'
      spec.Expect(filereadable(log)).ToBeFalse()
    finally
      if filereadable(log)
        delete(log)
      endif
      for name in ['keyhabits_auto_start', 'keyhabits_log_file', 'loaded_keyhabits']
        if exists('g:' .. name)
          execute 'unlet g:' .. name
        endif
      endfor
    endtry
  })
})
