vim9script

# Runs every test/*_spec.vim and reports a pass/fail tally.

import './spec.vim' as spec

var root: string = expand('<sfile>:p:h:h')
execute 'set runtimepath^=' .. fnameescape(root)

def Say(line: string)
  verbose echo line
enddef

var source_failures: number = 0

for file in sort(glob(root .. '/test/*_spec.vim', false, true))
  try
    execute 'source ' .. fnameescape(file)
  catch
    source_failures += 1
    Say($'FAIL {fnamemodify(file, ":t")}: {v:exception}')
  endtry
endfor

var tally: dict<number> = spec.Summary()
var failed: number = tally.failed + source_failures
Say($'passed: {tally.passed} failed: {failed}')
Say('')
if failed > 0
  cquit 1
endif
qall!
