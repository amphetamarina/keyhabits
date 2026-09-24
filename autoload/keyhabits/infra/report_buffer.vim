vim9script

# Renders a Report as text and shows it in a scratch buffer.

import autoload 'keyhabits/domain/stats.vim'

const buffer_name: string = 'keyhabits://report'

export def Render(report: dict<any>): list<string>
  var lines: list<string> = ['keyhabits report']
  if report.total_keys == 0
    add(lines, 'no events recorded')
    return lines
  endif
  add(lines, TimeLine(report))
  add(lines, $'keys: {report.total_keys}  sessions: {report.sessions}')
  AdviceSection(lines, report.advice)
  Section(lines, 'Top keys', report.top_keys)
  Section(lines, 'Top commands', report.top_commands)
  Section(lines, 'Top key pairs', report.top_bigrams)
  Section(lines, 'Modes', ModeRows(report.modes))
  Section(lines, 'Filetypes', report.filetypes)
  return lines
enddef

export def Open(lines: list<string>)
  var existing: number = bufnr(buffer_name)
  if existing > 0
    execute 'bwipeout! ' .. existing
  endif
  new
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setline(1, lines)
  execute 'file ' .. fnameescape(buffer_name)
  setlocal filetype=keyhabits-report
  setlocal nomodifiable
  cursor(1, 1)
enddef

def TimeLine(report: dict<any>): string
  var span: list<any> = report.time_span
  return 'from ' .. Stamp(span[0]) .. ' to ' .. Stamp(span[1])
enddef

def Stamp(ts: number): string
  return strftime('%Y-%m-%d %H:%M', ts)
enddef

def Section(lines: list<string>, title: string, rows: list<list<any>>)
  add(lines, '')
  add(lines, title)
  if len(rows) == 0
    add(lines, '  (none)')
    return
  endif
  for [name, count] in rows
    add(lines, printf('%6d  %s', count, name))
  endfor
enddef

def ModeRows(rows: list<list<any>>): list<list<any>>
  var counts: dict<number> = {}
  for [name, count] in rows
    var label: string = ModeLabel(name)
    counts[label] = get(counts, label, 0) + count
  endfor
  return stats.Top(counts, 0)
enddef

# A readable label for the first character of mode(1); anything unknown keeps
# its own code.
def ModeLabel(mode: string): string
  if mode == "\<C-V>"
    return 'Visual'
  endif
  if mode == ''
    return mode
  endif
  var labels: dict<string> = {
    n: 'Normal',
    i: 'Insert',
    v: 'Visual',
    V: 'Visual',
    c: 'Command-line',
    R: 'Replace',
    t: 'Terminal',
  }
  return get(labels, mode[0], mode[0])
enddef

# Each tip carries the keys it would have saved and the :help command for the
# documentation it comes from.
def AdviceSection(lines: list<string>, rows: list<dict<any>>)
  add(lines, '')
  add(lines, 'Advice (keys a better command would have saved)')
  if len(rows) == 0
    add(lines, '  (none)')
    return
  endif
  for row in rows
    add(lines, printf('%6d  %s  (:help %s)', row.saved, row.tip, row.help))
  endfor
enddef
