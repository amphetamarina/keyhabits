vim9script

# Reads the g:keyhabits_* options with the defaults from ARCHITECTURE.md.
# Nothing is cached: every call reflects the current values.

export def Load(): dict<any>
  return {
    log_file: LogFile(),
    auto_start: BoolOption('keyhabits_auto_start', true),
    flush_threshold: NumberOption('keyhabits_flush_threshold', 200),
    flush_interval: NumberOption('keyhabits_flush_interval', 30000),
    record_text: BoolOption('keyhabits_record_text', false),
    report_limit: NumberOption('keyhabits_report_limit', 20),
  }
enddef

def Option(name: string, fallback: any): any
  return get(g:, name, fallback)
enddef

# A bool stays a bool, a number becomes true when it is not zero, and anything
# else keeps the default.
def BoolOption(name: string, fallback: bool): bool
  var value: any = Option(name, fallback)
  if type(value) == v:t_bool
    return value
  endif
  if type(value) == v:t_number
    return value != 0
  endif
  return fallback
enddef

def NumberOption(name: string, fallback: number): number
  var value: any = Option(name, fallback)
  return type(value) == v:t_number ? value : fallback
enddef

def LogFile(): string
  var configured: any = Option('keyhabits_log_file', '')
  if type(configured) == v:t_string && configured != ''
    return expand(configured)
  endif
  return DefaultLogFile()
enddef

def DefaultLogFile(): string
  var data_home: string = $XDG_DATA_HOME
  if data_home == ''
    data_home = '~/.local/share'
  endif
  return expand(data_home .. '/keyhabits/events.jsonl')
enddef
