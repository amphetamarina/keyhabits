vim9script

# The advice catalogue and a pure matcher over lists of commands.
#
# Every tip comes from Vim's own help and names the tag it comes from, so the
# user can read the source with :help. A rule matches a run of consecutive
# commands, because SafeState ends a command after every plain motion: "jjjj"
# arrives as four "j" commands.

import autoload 'keyhabits/domain/event.vim'

# Fields of a rule:
#   id        stable name
#   sequence  regexes, each matched against one whole command, in order
#   min       how many times in a row the sequence must occur; a run of a
#             rule with min 1 is a single occurrence
#   same      optional; when true every repeat must be the same command as
#             the first, so "fa fa" matches and "fa fb" does not
#   inside    optional; when true the single regex matches parts of one
#             command, such as a run of <BS> inside an Insert, and each
#             part is one occurrence
#   fix       keys the better way takes, typed text not counted; the keys
#             saved are the keys of the run, or of the part, minus fix
#   fix_each  optional; keys the better way adds for every repeat after the
#             first, such as one ";" for each repeated "fx"
#   saves     instead of fix: the keys saved by each occurrence, for rules
#             whose commands carry an Insert of any length
#   tip       the better way, one line
#   help      the :help tag the tip comes from
#   example   commands that show the habit; a spec checks that the rule
#             matches them, that no earlier rule takes them, and that the
#             better way saves keys
#
# Rules are tried in order and the first match wins, so a longer habit comes
# before a shorter one that starts the same way.

# A text object after "i" or "a": iw, a", i(, it and the rest.
const object: string = '[ia]\%([wWsp()b{}B"''`t\[\]>]\|<lt>\)'

# Many tips give a repeated command a count. Counted() builds those: the
# command must repeat at least min times in a row, and the better way is the
# count followed by the command, fix keys in all.
def Counted(id: string, pattern: string, min: number, fix: number, tip: string, help: string, example: string): dict<any>
  return {
    id: id,
    sequence: [pattern],
    min: min,
    fix: fix,
    tip: tip,
    help: help,
    example: repeat([example], min),
  }
enddef

const rules: list<dict<any>> = [
  {
    id: 'end-then-append',
    sequence: ['^\$$', '^a'],
    min: 1,
    saves: 1,
    tip: 'Append at the end of the line with A instead of $a',
    help: 'A',
    example: ['$', 'a<text><Esc>'],
  },
  {
    id: 'first-then-insert',
    sequence: ['^\^$', '^i'],
    min: 1,
    saves: 1,
    tip: 'Insert before the first non-blank with I instead of ^i',
    help: 'I',
    example: ['^', 'i<text><Esc>'],
  },
  {
    id: 'delete-to-end-then-append',
    sequence: ['^\%(d\$\|D\)$', '^a'],
    min: 1,
    saves: 1,
    tip: 'Change to the end of the line with C instead of d$a or Da',
    help: 'C',
    example: ['d$', 'a<text><Esc>'],
  },
  {
    id: 'delete-object-then-insert',
    sequence: ['^d' .. object .. '$', '^i'],
    min: 1,
    saves: 1,
    tip: 'Change the text object in one go: ciw instead of diw then i',
    help: '04.8',
    example: ['diw', 'i<text><Esc>'],
  },
  {
    id: 'delete-line-then-open',
    sequence: ['^dd$', '^O'],
    min: 1,
    saves: 1,
    tip: 'Replace a line with cc instead of dd then O',
    help: 'cc',
    example: ['dd', 'O<text><Esc>'],
  },
  {
    id: 'x-then-insert',
    sequence: ['^x$', '^i'],
    min: 1,
    saves: 1,
    tip: 'Replace a character and start inserting with s instead of xi',
    help: 's',
    example: ['x', 'i<text><Esc>'],
  },
  {
    id: 'up-then-open-below',
    sequence: ['^k$', '^A<CR>'],
    min: 1,
    saves: 2,
    tip: 'Open a new line above with O instead of kA<CR>',
    help: 'O',
    example: ['k', 'A<CR><text><Esc>'],
  },
  {
    id: 'down-to-first-non-blank',
    sequence: ['^j$', '^[\^_]$'],
    min: 1,
    saves: 1,
    tip: 'Go to the first non-blank of the next line with + instead of j^',
    help: '+',
    example: ['j', '^'],
  },
  {
    id: 'up-to-first-non-blank',
    sequence: ['^k$', '^[\^_]$'],
    min: 1,
    saves: 1,
    tip: 'Go to the first non-blank of the line above with - instead of k^',
    help: '-',
    example: ['k', '^'],
  },
  {
    id: 'left-then-delete',
    sequence: ['^h$', '^x$'],
    min: 1,
    saves: 1,
    tip: 'Delete the character before the cursor with X instead of hx',
    help: 'X',
    example: ['h', 'x'],
  },
  {
    id: 'left-then-append',
    sequence: ['^h$', '^a'],
    min: 1,
    saves: 1,
    tip: 'Insert before the cursor with i instead of ha',
    help: 'i',
    example: ['h', 'a<text><Esc>'],
  },
  {
    id: 'right-then-insert',
    sequence: ['^l$', '^i'],
    min: 1,
    saves: 1,
    tip: 'Append after the cursor with a instead of li',
    help: 'a',
    example: ['l', 'i<text><Esc>'],
  },
  {
    id: 'delete-motion-then-insert',
    sequence: ['^d\%([eEbB]\|[tTfF].\)$', '^i'],
    min: 1,
    saves: 1,
    tip: 'Change with the motion in one go: ce, ct) instead of de then i',
    help: 'c',
    example: ['dt)', 'i<text><Esc>'],
  },
  {
    id: 'delete-word-then-space',
    sequence: ['^diw$', '^x$'],
    min: 1,
    saves: 1,
    tip: 'Delete a word and the space after it with daw instead of diwx',
    help: 'aw',
    example: ['diw', 'x'],
  },
  {
    id: 'dot-after-dd',
    sequence: ['^dd$', '^\.$', '^\.$'],
    min: 1,
    fix: 3,
    tip: 'Delete several lines at once with a count: 3dd instead of dd..',
    help: 'dd',
    example: ['dd', '.', '.'],
  },
  {
    id: 'dot-after-x',
    sequence: ['^x$', '^\.$', '^\.$'],
    min: 1,
    fix: 2,
    tip: 'Delete several characters at once with a count: 3x instead of x..',
    help: 'x',
    example: ['x', '.', '.'],
  },
  {
    id: 'dot-after-dw',
    sequence: ['^dw$', '^\.$', '^\.$'],
    min: 1,
    fix: 3,
    tip: 'Delete several words at once with a count: d3w instead of dw..',
    help: '04.1',
    example: ['dw', '.', '.'],
  },
  {
    id: 'append-new-line',
    sequence: ['^A<CR>'],
    min: 1,
    saves: 1,
    tip: 'Open a new line below with o instead of A<CR>',
    help: 'o',
    example: ['A<CR><text><Esc>'],
  },
  {
    id: 'backspace-run',
    sequence: ['\%(<BS>\)\{5,}'],
    min: 1,
    inside: true,
    fix: 1,
    tip: 'Delete the word before the cursor with CTRL-W instead of <BS><BS><BS>',
    help: 'i_CTRL-W',
    example: ['a<text><BS><BS><BS><BS><BS><text><Esc>'],
  },
  {
    id: 'insert-left-run',
    sequence: ['\%(<Left>\)\{4,}'],
    min: 1,
    inside: true,
    fix: 2,
    tip: 'Move back by words in Insert mode with <C-Left> instead of <Left>',
    help: 'i_<C-Left>',
    example: ['a<text><Left><Left><Left><Left><text><Esc>'],
  },
  {
    id: 'insert-right-run',
    sequence: ['\%(<Right>\)\{4,}'],
    min: 1,
    inside: true,
    fix: 2,
    tip: 'Move forward by words in Insert mode with <C-Right> instead of <Right>',
    help: 'i_<C-Right>',
    example: ['a<text><Right><Right><Right><Right><text><Esc>'],
  },
  {
    id: 'far-j',
    sequence: ['^\%(j\|<Down>\)$'],
    min: 15,
    fix: 2,
    tip: 'Scroll half a screen with CTRL-D instead of holding j',
    help: 'CTRL-D',
    example: repeat(['j'], 15),
  },
  {
    id: 'far-k',
    sequence: ['^\%(k\|<Up>\)$'],
    min: 15,
    fix: 2,
    tip: 'Scroll half a screen with CTRL-U instead of holding k',
    help: 'CTRL-U',
    example: repeat(['k'], 15),
  },
  {
    id: 'repeated-j',
    sequence: ['^\%(j\|<Down>\)$'],
    min: 4,
    fix: 2,
    tip: 'Give the motion a count instead of repeating j: 5j',
    help: 'count',
    example: ['j', 'j', 'j', 'j'],
  },
  {
    id: 'repeated-k',
    sequence: ['^\%(k\|<Up>\)$'],
    min: 4,
    fix: 2,
    tip: 'Give the motion a count instead of repeating k: 5k',
    help: 'count',
    example: ['k', 'k', 'k', 'k'],
  },
  {
    id: 'far-l',
    sequence: ['^\%(l\|<Right>\|<Space>\)$'],
    min: 8,
    fix: 2,
    tip: 'Jump to a character further along the line with f{char}',
    help: '03.3',
    example: repeat(['l'], 8),
  },
  {
    id: 'far-h',
    sequence: ['^\%(h\|<Left>\|<BS>\)$'],
    min: 8,
    fix: 2,
    tip: 'Jump back to a character on the line with F{char}',
    help: '03.3',
    example: repeat(['h'], 8),
  },
  {
    id: 'repeated-l',
    sequence: ['^\%(l\|<Right>\|<Space>\)$'],
    min: 4,
    fix: 2,
    tip: 'Move by words with w or e instead of repeating l',
    help: 'word-motions',
    example: ['l', 'l', 'l', 'l'],
  },
  {
    id: 'repeated-h',
    sequence: ['^\%(h\|<Left>\|<BS>\)$'],
    min: 4,
    fix: 2,
    tip: 'Move back by words with b instead of repeating h',
    help: 'word-motions',
    example: ['h', 'h', 'h', 'h'],
  },
  {
    id: 'repeated-w',
    sequence: ['^w$'],
    min: 4,
    fix: 2,
    tip: 'Give the word motion a count instead of repeating w: 3w',
    help: '03.1',
    example: ['w', 'w', 'w', 'w'],
  },
  {
    id: 'repeated-b',
    sequence: ['^b$'],
    min: 4,
    fix: 2,
    tip: 'Give the word motion a count instead of repeating b: 3b',
    help: '03.1',
    example: ['b', 'b', 'b', 'b'],
  },
  {
    id: 'repeated-e',
    sequence: ['^e$'],
    min: 4,
    fix: 2,
    tip: 'Give the word motion a count instead of repeating e: 3e',
    help: '03.1',
    example: ['e', 'e', 'e', 'e'],
  },
  Counted('repeated-W', '^W$', 4, 2, 'Give the WORD motion a count instead of repeating W: 3W', 'W', 'W'),
  Counted('repeated-B', '^B$', 4, 2, 'Give the WORD motion a count instead of repeating B: 3B', 'B', 'B'),
  Counted('repeated-E', '^E$', 4, 2, 'Give the WORD motion a count instead of repeating E: 3E', 'E', 'E'),
  Counted('repeated-ge', '^ge$', 3, 3, 'Give ge a count instead of repeating it: 3ge', 'ge', 'ge'),
  Counted('repeated-gE', '^gE$', 3, 3, 'Give gE a count instead of repeating it: 3gE', 'gE', 'gE'),
  Counted('repeated-paragraph-forward', '^}$', 3, 2, 'Move several paragraphs at once with a count: 3}', '}', '}'),
  Counted('repeated-paragraph-back', '^{$', 3, 2, 'Move back several paragraphs at once with a count: 3{', '{', '{'),
  Counted('repeated-sentence-forward', '^)$', 3, 2, 'Move several sentences at once with a count: 3)', ')', ')'),
  Counted('repeated-sentence-back', '^($', 3, 2, 'Move back several sentences at once with a count: 3(', '(', '('),
  Counted('repeated-plus', '^\%(+\|<CR>\)$', 4, 2, 'Move several lines to the first non-blank with a count: 5+', '+', '+'),
  Counted('repeated-minus', '^-$', 4, 2, 'Move several lines up to the first non-blank with a count: 5-', '-', '-'),
  Counted('repeated-display-down', '^\%(gj\|g<Down>\)$', 4, 3, 'Give gj a count instead of repeating it: 5gj', 'gj', 'gj'),
  Counted('repeated-display-up', '^\%(gk\|g<Up>\)$', 4, 3, 'Give gk a count instead of repeating it: 5gk', 'gk', 'gk'),
  Counted('repeated-next-match', '^n$', 4, 2, 'Skip ahead several matches at once with a count: 3n', 'n', 'n'),
  Counted('repeated-previous-match', '^N$', 4, 2, 'Skip back several matches at once with a count: 3N', 'N', 'N'),
  Counted('repeated-star', '^\*$', 3, 2, 'Jump to the third match of the word at once: 3*', 'star', '*'),
  Counted('repeated-hash', '^#$', 3, 2, 'Jump back to the third match of the word at once: 3#', '#', '#'),
  Counted('repeated-semicolon', '^;$', 4, 2, 'Give ; a count instead of repeating it: 3;', ';', ';'),
  Counted('repeated-comma', '^,$', 4, 2, 'Give , a count instead of repeating it: 3,', ',', ','),
  Counted('repeated-page-forward', '^\%(<C-F>\|<PageDown>\)$', 3, 2, 'Scroll several pages at once with a count: 3 CTRL-F', 'CTRL-F', '<C-F>'),
  Counted('repeated-page-back', '^\%(<C-B>\|<PageUp>\)$', 3, 2, 'Scroll back several pages at once with a count: 3 CTRL-B', 'CTRL-B', '<C-B>'),
  Counted('repeated-jump-older', '^<C-O>$', 3, 2, 'Go back several jumps at once with a count: 3 CTRL-O', 'CTRL-O', '<C-O>'),
  Counted('repeated-jump-newer', '^<Tab>$', 3, 2, 'Go forward several jumps at once with a count: 3 CTRL-I', 'CTRL-I', '<Tab>'),
  Counted('repeated-change-older', '^g;$', 3, 3, 'Go back several changes at once with a count: 3g;', 'g;', 'g;'),
  Counted('repeated-change-newer', '^g,$', 3, 3, 'Go forward several changes at once with a count: 3g,', 'g,', 'g,'),
  Counted('repeated-next-spelling', '^\]s$', 3, 3, 'Skip several misspelled words at once with a count: 3]s', ']s', ']s'),
  Counted('repeated-previous-spelling', '^\[s$', 3, 3, 'Skip back several misspelled words at once with a count: 3[s', '[s', '[s'),
  Counted('repeated-next-diff', '^\]c$', 3, 3, 'Skip several diff changes at once with a count: 3]c', ']c', ']c'),
  Counted('repeated-previous-diff', '^\[c$', 3, 3, 'Skip back several diff changes at once with a count: 3[c', '[c', '[c'),
  Counted('repeated-next-section', '^\]\]$', 3, 3, 'Move several sections at once with a count: 3]]', ']]', ']]'),
  Counted('repeated-previous-section', '^\[\[$', 3, 3, 'Move back several sections at once with a count: 3[[', '[[', '[['),
  Counted('repeated-scroll-left', '^zh$', 4, 3, 'Scroll the view several columns at once with a count: 5zh', 'zh', 'zh'),
  Counted('repeated-scroll-right', '^zl$', 4, 3, 'Scroll the view several columns at once with a count: 5zl', 'zl', 'zl'),
  Counted('repeated-previous-tab', '^gT$', 3, 3, 'Go back several tab pages at once with a count: 3gT', 'gT', 'gT'),
  Counted('repeated-redo', '^<C-R>$', 4, 2, 'Redo several changes at once with a count: 4 CTRL-R', 'CTRL-R', '<C-R>'),
  Counted('repeated-increment', '^<C-A>$', 3, 2, 'Add to a number in one go with a count: 5 CTRL-A', 'CTRL-A', '<C-A>'),
  Counted('repeated-decrement', '^<C-X>$', 3, 2, 'Subtract from a number in one go with a count: 5 CTRL-X', 'CTRL-X', '<C-X>'),
  Counted('repeated-macro-again', '^@@$', 3, 3, 'Replay the macro several times at once with a count: 3@@', '@@', '@@'),
  Counted('window-taller', '^<C-W>+$', 3, 3, 'Make the window taller in one go with a count: 5 CTRL-W +', 'CTRL-W_+', '<C-W>+'),
  Counted('window-shorter', '^<C-W>-$', 3, 3, 'Make the window shorter in one go with a count: 5 CTRL-W -', 'CTRL-W_-', '<C-W>-'),
  Counted('window-wider', '^<C-W>>$', 3, 3, 'Make the window wider in one go with a count: 5 CTRL-W >', 'CTRL-W_>', '<C-W>>'),
  Counted('window-narrower', '^<C-W><lt>$', 3, 3, 'Make the window narrower in one go with a count: 5 CTRL-W <', 'CTRL-W_<', '<C-W><lt>'),
  {
    id: 'repeated-macro',
    sequence: ['^@[a-z0-9:]$'],
    min: 3,
    same: true,
    fix: 3,
    tip: 'Run the macro several times at once with a count: 3@a',
    help: '@',
    example: ['@a', '@a', '@a'],
  },
  {
    id: 'repeated-indent',
    sequence: ['^>>$'],
    min: 3,
    fix: 3,
    tip: 'Shift a line several times at once from Visual mode: V3>',
    help: 'v_>',
    example: ['>>', '>>', '>>'],
  },
  {
    id: 'repeated-unindent',
    sequence: ['^<lt><lt>$'],
    min: 3,
    fix: 3,
    tip: 'Shift a line back several times at once from Visual mode: V3<',
    help: 'v_<',
    example: ['<lt><lt>', '<lt><lt>', '<lt><lt>'],
  },
  {
    id: 'repeated-find',
    sequence: ['^[fFtT].$'],
    min: 2,
    same: true,
    fix: 2,
    fix_each: 1,
    tip: 'Repeat the last f, t, F or T with ; instead of typing it again',
    help: ';',
    example: ['f(', 'f('],
  },
  {
    id: 'repeated-word-operator',
    sequence: ['^d[wWeEbBjk(){}]$'],
    min: 2,
    same: true,
    fix: 3,
    tip: 'Give the operator a count instead of repeating it: d3w, d3j',
    help: '04.1',
    example: ['dw', 'dw'],
  },
  {
    id: 'repeated-x',
    sequence: ['^\%(x\|<Del>\)$'],
    min: 3,
    fix: 2,
    tip: 'Delete with a count or a motion instead of repeating x: 4x, dw',
    help: '04.1',
    example: ['x', 'x', 'x'],
  },
  {
    id: 'repeated-X',
    sequence: ['^X$'],
    min: 3,
    fix: 2,
    tip: 'Give X a count instead of repeating it: 3X',
    help: 'X',
    example: ['X', 'X', 'X'],
  },
  {
    id: 'repeated-dd',
    sequence: ['^dd$'],
    min: 2,
    fix: 3,
    tip: 'Give dd a count instead of repeating it: 3dd',
    help: 'dd',
    example: ['dd', 'dd'],
  },
  {
    id: 'repeated-J',
    sequence: ['^J$'],
    min: 3,
    fix: 2,
    tip: 'Join several lines at once with a count: 4J',
    help: 'J',
    example: ['J', 'J', 'J'],
  },
  {
    id: 'repeated-put',
    sequence: ['^[pP]$'],
    min: 3,
    same: true,
    fix: 2,
    tip: 'Put several copies at once with a count: 3p',
    help: 'p',
    example: ['p', 'p', 'p'],
  },
  {
    id: 'repeated-undo',
    sequence: ['^u$'],
    min: 4,
    fix: 2,
    tip: 'Undo several changes at once with a count: 4u',
    help: 'u',
    example: ['u', 'u', 'u', 'u'],
  },
  {
    id: 'repeated-scroll-down',
    sequence: ['^<C-E>$'],
    min: 4,
    fix: 2,
    tip: 'Scroll several lines at once with a count: 5 CTRL-E',
    help: 'CTRL-E',
    example: ['<C-E>', '<C-E>', '<C-E>', '<C-E>'],
  },
  {
    id: 'repeated-scroll-up',
    sequence: ['^<C-Y>$'],
    min: 4,
    fix: 2,
    tip: 'Scroll several lines at once with a count: 5 CTRL-Y',
    help: 'CTRL-Y',
    example: ['<C-Y>', '<C-Y>', '<C-Y>', '<C-Y>'],
  },
  {
    id: 'repeated-case',
    sequence: ['^\~$'],
    min: 3,
    fix: 2,
    tip: 'Switch the case of several characters with a count: 4~',
    help: '~',
    example: ['~', '~', '~'],
  },
  {
    id: 'repeated-blank-line',
    sequence: ['^[oO]<Esc>$'],
    min: 3,
    same: true,
    fix: 3,
    tip: 'Open several blank lines at once with a count: 3o<Esc>',
    help: 'o',
    example: ['o<Esc>', 'o<Esc>', 'o<Esc>'],
  },
  {
    id: 'visual-lines-delete',
    sequence: ['^Vj\{2,}d$'],
    min: 1,
    fix: 3,
    tip: 'Delete several lines with a count instead of selecting them: 3dd',
    help: 'dd',
    example: ['Vjjd'],
  },
  {
    id: 'visual-lines-yank',
    sequence: ['^Vj\{2,}y$'],
    min: 1,
    fix: 3,
    tip: 'Yank several lines with a count instead of selecting them: 3yy',
    help: 'yy',
    example: ['Vjjy'],
  },
  {
    id: 'visual-word-end-then-operate',
    sequence: ['^v[eE][dy]$'],
    min: 1,
    fix: 2,
    tip: 'Apply the operator with the motion directly: de, ye',
    help: '04.1',
    example: ['ved'],
  },
  {
    id: 'visual-lines-shift-right',
    sequence: ['^Vj\{2,}>$'],
    min: 1,
    fix: 3,
    tip: 'Shift several lines with a count instead of selecting them: 3>>',
    help: '>>',
    example: ['Vjj>'],
  },
  {
    id: 'visual-lines-shift-left',
    sequence: ['^Vj\{2,}<lt>$'],
    min: 1,
    fix: 3,
    tip: 'Shift several lines back with a count instead of selecting them: 3<<',
    help: '<<',
    example: ['Vjj<lt>'],
  },
  {
    id: 'visual-lines-filter',
    sequence: ['^Vj\{2,}=$'],
    min: 1,
    fix: 3,
    tip: 'Re-indent several lines with a count instead of selecting them: 3==',
    help: '==',
    example: ['Vjj='],
  },
  {
    id: 'visual-lines-join',
    sequence: ['^Vj\{2,}J$'],
    min: 1,
    fix: 2,
    tip: 'Join several lines with a count instead of selecting them: 3J',
    help: 'J',
    example: ['VjjJ'],
  },
  {
    id: 'visual-join-two',
    sequence: ['^Vj\=J$'],
    min: 1,
    fix: 1,
    tip: 'Join two lines with J, no selection needed',
    help: 'J',
    example: ['VjJ'],
  },
  {
    id: 'visual-lines-change',
    sequence: ['^Vj\{2,}c'],
    min: 1,
    saves: 1,
    tip: 'Change several lines with a count instead of selecting them: 3cc',
    help: 'cc',
    example: ['Vjjc<text><Esc>'],
  },
  {
    id: 'visual-to-last-line',
    sequence: ['^VG\%([=dy>]\|<lt>\)$'],
    min: 1,
    fix: 2,
    tip: 'Apply the operator up to the last line directly: dG, =G',
    help: 'G',
    example: ['VG='],
  },
  {
    id: 'visual-to-first-line',
    sequence: ['^Vgg\%([=dy>]\|<lt>\)$'],
    min: 1,
    fix: 3,
    tip: 'Apply the operator up to the first line directly: dgg, =gg',
    help: 'gg',
    example: ['Vggd'],
  },
  {
    id: 'visual-character-delete',
    sequence: ['^v[dx]$'],
    min: 1,
    fix: 1,
    tip: 'Delete one character with x instead of selecting it',
    help: 'x',
    example: ['vd'],
  },
  {
    id: 'visual-character-change',
    sequence: ['^v[cs]'],
    min: 1,
    saves: 1,
    tip: 'Replace one character and insert with s instead of selecting it',
    help: 's',
    example: ['vc<text><Esc>'],
  },
  {
    id: 'visual-character-replace',
    sequence: ['^vr.$'],
    min: 1,
    fix: 2,
    tip: 'Replace one character with r{char} instead of selecting it',
    help: 'r',
    example: ['vrx'],
  },
  {
    id: 'visual-character-case',
    sequence: ['^v\~$'],
    min: 1,
    fix: 1,
    tip: 'Switch the case of one character with ~ instead of selecting it',
    help: '~',
    example: ['v~'],
  },
  {
    id: 'select-object-then-operate',
    sequence: ['^v' .. object .. '[dy]$'],
    min: 1,
    fix: 3,
    tip: 'Apply the operator to the text object directly: diw, ya"',
    help: '04.8',
    example: ['viwd'],
  },
  {
    id: 'select-object-then-change',
    sequence: ['^v' .. object .. 'c'],
    min: 1,
    saves: 1,
    tip: 'Change the text object directly: ciw, ci"',
    help: '04.8',
    example: ['vi"c<text><Esc>'],
  },
  {
    id: 'delete-right',
    sequence: ['^dl$'],
    min: 1,
    fix: 1,
    tip: 'Delete the character under the cursor with x instead of dl',
    help: 'x',
    example: ['dl'],
  },
  {
    id: 'delete-left',
    sequence: ['^dh$'],
    min: 1,
    fix: 1,
    tip: 'Delete the character before the cursor with X instead of dh',
    help: 'X',
    example: ['dh'],
  },
  {
    id: 'change-character',
    sequence: ['^cl'],
    min: 1,
    saves: 1,
    tip: 'Replace a character and start inserting with s instead of cl',
    help: 's',
    example: ['cl<text><Esc>'],
  },
  {
    id: 'delete-to-end',
    sequence: ['^d\$$'],
    min: 1,
    fix: 1,
    tip: 'Delete to the end of the line with D instead of d$',
    help: 'D',
    example: ['d$'],
  },
  {
    id: 'change-to-end',
    sequence: ['^c\$'],
    min: 1,
    saves: 1,
    tip: 'Change to the end of the line with C instead of c$',
    help: 'C',
    example: ['c$<text><Esc>'],
  },
]

# Which catalogue rules can start at a command, remembered across calls for
# the catalogue itself. Forgotten when it grows large, since typed
# variations such as f{char} make the commands open-ended.
const max_remembered: number = 2000
var catalogue_starters: dict<list<dict<any>>> = {}

export def Rules(): list<dict<any>>
  return rules
enddef

# Keys typed for a command. Typed text is left out: it is the same whichever
# way the command is written.
export def KeyCount(command: string): number
  var without_text: string = substitute(command, event.PLACEHOLDER, '', 'g')
  return strcharlen(substitute(without_text, '<[^<>]\+>', '.', 'g'))
enddef

# How many commands a run of the rule consumes at start, or 0 if the rule does
# not match there.
def RunLength(commands: list<string>, start: number, rule: dict<any>): number
  var sequence: list<string> = rule.sequence
  var index: number = start
  var repeats: number = 0
  while SequenceAt(commands, index, sequence) && (repeats == 0 || rule.min > 1)
    if repeats > 0 && get(rule, 'same', false) && !SameAsFirst(commands, start, index, len(sequence))
      break
    endif
    index += len(sequence)
    repeats += 1
  endwhile
  return repeats >= rule.min ? index - start : 0
enddef

def SequenceAt(commands: list<string>, start: number, sequence: list<string>): bool
  if start + len(sequence) > len(commands)
    return false
  endif
  for offset in range(len(sequence))
    if commands[start + offset] !~# sequence[offset]
      return false
    endif
  endfor
  return true
enddef

def SameAsFirst(commands: list<string>, first: number, index: number, size: number): bool
  return commands[index : index + size - 1] == commands[first : first + size - 1]
enddef

def RunKeys(commands: list<string>): number
  var total: number = 0
  for command in commands
    total += KeyCount(command)
  endfor
  return total
enddef

# The parts of one command an inside rule matches, left to right.
def Parts(command: string, pattern: string): list<string>
  var parts: list<string> = []
  var found: list<any> = matchstrpos(command, pattern)
  while found[1] >= 0
    add(parts, found[0])
    found = matchstrpos(command, pattern, found[2])
  endwhile
  return parts
enddef

def Saved(rule: dict<any>, keys: number, repeats: number): number
  if has_key(rule, 'saves')
    return rule.saves
  endif
  return max([0, keys - rule.fix - get(rule, 'fix_each', 0) * (repeats - 1)])
enddef

def Add(found: dict<dict<number>>, id: string, runs: number, saved: number)
  var tally: dict<number> = get(found, id, {runs: 0, saved: 0})
  tally.runs += runs
  tally.saved += saved
  found[id] = tally
enddef

# How many commands the rule takes at index, adding what it found; 0 when it
# does not match there.
def Take(commands: list<string>, index: number, rule: dict<any>, found: dict<dict<number>>): number
  if get(rule, 'inside', false)
    var parts: list<string> = Parts(commands[index], rule.sequence[0])
    for part in parts
      Add(found, rule.id, 1, Saved(rule, KeyCount(part), 1))
    endfor
    return len(parts) > 0 ? 1 : 0
  endif
  var consumed: number = RunLength(commands, index, rule)
  if consumed > 0
    var run: list<string> = commands[index : index + consumed - 1]
    Add(found, rule.id, 1, Saved(rule, RunKeys(run), consumed / len(rule.sequence)))
  endif
  return consumed
enddef

# Scans the commands once. At each position the first rule that matches wins
# and its run is consumed, so a run is counted once. Returns, per rule id, the
# number of runs and the keys the better way would have saved.
export def Match(commands: list<string>, candidates: list<dict<any>>): dict<dict<number>>
  var found: dict<dict<number>> = {}
  # The rules that can start at a command depend only on the command, and the
  # same few commands repeat, so each distinct one is checked against the
  # catalogue once. This keeps matching cheap enough to run after every key.
  if len(catalogue_starters) > max_remembered
    catalogue_starters = {}
  endif
  var starters: dict<list<dict<any>>> = candidates is rules ? catalogue_starters : {}
  var index: number = 0
  while index < len(commands)
    var command: string = commands[index]
    if !has_key(starters, command)
      starters[command] = filter(copy(candidates), (_, rule: dict<any>): bool => command =~# rule.sequence[0])
    endif
    var consumed: number = 0
    for rule in starters[command]
      consumed = Take(commands, index, rule, found)
      if consumed > 0
        break
      endif
    endfor
    index += consumed > 0 ? consumed : 1
  endwhile
  return found
enddef

# A command is covered when some rule looks at it at all, even if this run
# was too short for the rule.
def IsCovered(command: string, candidates: list<dict<any>>): bool
  for rule in candidates
    for pattern in rule.sequence
      if command =~# pattern
        return true
      endif
    endfor
  endfor
  return false
enddef

# Runs of the same command, three or more in a row, that no rule covers:
# habits the catalogue has no tip for yet. Returns, per command, the number
# of runs and the presses in them.
export def Uncovered(commands: list<string>, candidates: list<dict<any>>): dict<dict<number>>
  var found: dict<dict<number>> = {}
  var index: number = 0
  while index < len(commands)
    var next: number = index
    while next < len(commands) && commands[next] ==# commands[index]
      next += 1
    endwhile
    if next - index >= 3 && !IsCovered(commands[index], candidates)
      var tally: dict<number> = get(found, commands[index], {runs: 0, presses: 0})
      tally.runs += 1
      tally.presses += next - index
      found[commands[index]] = tally
    endif
    index = next
  endwhile
  return found
enddef
