vim9script

# Specs for rendering a report and showing it in a scratch buffer.

import './spec.vim' as spec
import autoload 'keyhabits/infra/report_buffer.vim'

const buffer_name: string = 'keyhabits://report'

def Report(overrides: dict<any>): dict<any>
  return extend({
    total_keys: 3,
    sessions: 1,
    time_span: [1700000000, 1700000100],
    top_keys: [['j', 2], ['k', 1]],
    top_commands: [['ciw', 1]],
    top_bigrams: [['jj', 1]],
    modes: [['n', 2], ['ce', 1]],
    filetypes: [['vim', 3]],
    advice: [{tip: 'Use 5j', help: 'count', runs: 2, saved: 6}],
  }, overrides)
enddef

def EmptyReport(): dict<any>
  return {
    total_keys: 0,
    sessions: 0,
    time_span: [0, 0],
    top_keys: [],
    top_commands: [],
    top_bigrams: [],
    modes: [],
    filetypes: [],
    advice: [],
  }
enddef

spec.Describe('report_buffer.Render', () => {
  spec.It('renders an empty report as a title and a notice', () => {
    spec.Expect(report_buffer.Render(EmptyReport())).ToEqual(
      ['keyhabits report', 'no events recorded'])
  })

  spec.It('renders the span, the counters and every section', () => {
    var from: string = strftime('%Y-%m-%d %H:%M', 1700000000)
    var to: string = strftime('%Y-%m-%d %H:%M', 1700000100)
    spec.Expect(report_buffer.Render(Report({}))).ToEqual([
      'keyhabits report',
      $'from {from} to {to}',
      'keys: 3  sessions: 1',
      '',
      'Advice (keys a better command would have saved)',
      '     6  Use 5j  (:help count)',
      '',
      'Top keys',
      '     2  j',
      '     1  k',
      '',
      'Top commands',
      '     1  ciw',
      '',
      'Top key pairs',
      '     1  jj',
      '',
      'Modes',
      '     2  Normal',
      '     1  Command-line',
      '',
      'Filetypes',
      '     3  vim',
    ])
  })

  spec.It('prints (none) for an empty section', () => {
    var lines: list<string> = report_buffer.Render(Report({top_keys: []}))
    var title: number = index(lines, 'Top keys')
    spec.Expect(title >= 0).ToBeTrue()
    spec.Expect(lines[title + 1]).ToEqual('  (none)')
  })

  spec.It('prints (none) when there is no advice', () => {
    var lines: list<string> = report_buffer.Render(Report({advice: []}))
    var title: number = index(lines, 'Advice (keys a better command would have saved)')
    spec.Expect(title >= 0).ToBeTrue()
    spec.Expect(lines[title + 1]).ToEqual('  (none)')
  })

  spec.It('labels the modes and merges the ones that share a label', () => {
    var modes: list<list<any>> = [['n', 1], ['i', 1], ['v', 1], ['V', 1], ["\<C-V>", 1], ['c', 1], ['R', 1], ['t', 1], ['x', 1]]
    var lines: list<string> = report_buffer.Render(Report({modes: modes}))
    var title: number = index(lines, 'Modes')
    spec.Expect(lines[title + 1 : title + 7]).ToEqual([
      '     3  Visual',
      '     1  Command-line',
      '     1  Insert',
      '     1  Normal',
      '     1  Replace',
      '     1  Terminal',
      '     1  x',
    ])
  })

  spec.It('adds up the rows of the modes that share a label', () => {
    var modes: list<list<any>> = [['n', 5], ['no', 3], ['i', 4]]
    var lines: list<string> = report_buffer.Render(Report({modes: modes}))
    var title: number = index(lines, 'Modes')
    spec.Expect(lines[title + 1 : title + 2]).ToEqual([
      '     8  Normal',
      '     4  Insert',
    ])
  })
})

spec.Describe('report_buffer.Open', () => {
  spec.It('opens a scratch buffer with the lines and replaces it next time', () => {
    var lines: list<string> = ['one', 'two']
    try
      report_buffer.Open(lines)
      spec.Expect(bufname('%')).ToEqual(buffer_name)
      spec.Expect(&buftype).ToEqual('nofile')
      spec.Expect(&bufhidden).ToEqual('wipe')
      spec.Expect(&swapfile).ToBeFalse()
      spec.Expect(&filetype).ToEqual('keyhabits-report')
      spec.Expect(&modifiable).ToBeFalse()
      spec.Expect(getline(1, '$')).ToEqual(lines)
      spec.Expect(line('.')).ToEqual(1)

      report_buffer.Open(['three'])
      spec.Expect(bufname('%')).ToEqual(buffer_name)
      spec.Expect(getline(1, '$')).ToEqual(['three'])
      spec.Expect(line('.')).ToEqual(1)
    finally
      var existing: number = bufnr(buffer_name)
      if existing > 0
        execute 'bwipeout! ' .. existing
      endif
    endtry
  })
})
