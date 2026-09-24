vim9script

# Specs for the configuration loader. Each spec runs through Isolated(), so it
# starts with no keyhabits options and no $XDG_DATA_HOME and cannot leak state
# into another spec.

import './spec.vim' as spec
import autoload 'keyhabits/config.vim'

const option_names: list<string> = [
  'keyhabits_log_file',
  'keyhabits_auto_start',
  'keyhabits_flush_threshold',
  'keyhabits_flush_interval',
  'keyhabits_record_text',
  'keyhabits_report_limit',
  'keyhabits_nudge',
  'keyhabits_nudge_threshold',
  'keyhabits_nudge_window',
  'keyhabits_nudge_cooldown',
]

def SaveSettings(): dict<any>
  var saved: dict<any> = {data_home: exists('$XDG_DATA_HOME') ? $XDG_DATA_HOME : false}
  for name in option_names
    if exists('g:' .. name)
      saved[name] = get(g:, name)
    endif
  endfor
  return saved
enddef

def ResetSettings()
  for name in option_names
    if exists('g:' .. name)
      execute 'unlet g:' .. name
    endif
  endfor
  if exists('$XDG_DATA_HOME')
    unlet $XDG_DATA_HOME
  endif
enddef

def RestoreSettings(saved: dict<any>)
  ResetSettings()
  for name in option_names
    if has_key(saved, name)
      g:[name] = saved[name]
    endif
  endfor
  if type(saved.data_home) == v:t_string
    $XDG_DATA_HOME = saved.data_home
  endif
enddef

def Isolated(Body: func())
  var saved: dict<any> = SaveSettings()
  ResetSettings()
  try
    Body()
  finally
    RestoreSettings(saved)
  endtry
enddef

def DefaultLogFile(): string
  return expand('~/.local/share/keyhabits/events.jsonl')
enddef

def ExpectedDefaults(): dict<any>
  return {
    log_file: DefaultLogFile(),
    auto_start: true,
    flush_threshold: 200,
    flush_interval: 30000,
    record_text: false,
    report_limit: 20,
    nudge: false,
    nudge_threshold: 1,
    nudge_window: 60,
    nudge_cooldown: 600,
  }
enddef

spec.Describe('config.Load', () => {
  spec.It('returns the documented defaults', () => {
    Isolated(() => {
      spec.Expect(config.Load()).ToEqual(ExpectedDefaults())
    })
  })

  spec.It('returns every overridden option', () => {
    Isolated(() => {
      g:keyhabits_log_file = '~/keyhabits/custom.jsonl'
      g:keyhabits_auto_start = 0
      g:keyhabits_flush_threshold = 5
      g:keyhabits_flush_interval = 1000
      g:keyhabits_record_text = 1
      g:keyhabits_report_limit = 3
      g:keyhabits_nudge = 1
      g:keyhabits_nudge_threshold = 2
      g:keyhabits_nudge_window = 30
      g:keyhabits_nudge_cooldown = 120
      var loaded: dict<any> = config.Load()
      spec.Expect(loaded.log_file).ToEqual(expand('~/keyhabits/custom.jsonl'))
      spec.Expect(loaded.auto_start).ToBeFalse()
      spec.Expect(loaded.flush_threshold).ToEqual(5)
      spec.Expect(loaded.flush_interval).ToEqual(1000)
      spec.Expect(loaded.record_text).ToBeTrue()
      spec.Expect(loaded.report_limit).ToEqual(3)
      spec.Expect(loaded.nudge).ToBeTrue()
      spec.Expect(loaded.nudge_threshold).ToEqual(2)
      spec.Expect(loaded.nudge_window).ToEqual(30)
      spec.Expect(loaded.nudge_cooldown).ToEqual(120)
    })
  })

  spec.It('returns the boolean options as bools', () => {
    Isolated(() => {
      g:keyhabits_auto_start = 1
      g:keyhabits_record_text = 0
      var loaded: dict<any> = config.Load()
      spec.Expect(type(loaded.auto_start)).ToEqual(v:t_bool)
      spec.Expect(type(loaded.record_text)).ToEqual(v:t_bool)
      spec.Expect(loaded.auto_start).ToBeTrue()
      spec.Expect(loaded.record_text).ToBeFalse()
    })
  })

  spec.It('uses $XDG_DATA_HOME for the default log file', () => {
    Isolated(() => {
      $XDG_DATA_HOME = '/xdg/data'
      spec.Expect(config.Load().log_file).ToEqual('/xdg/data/keyhabits/events.jsonl')
    })
  })

  spec.It('falls back to ~/.local/share when $XDG_DATA_HOME is empty', () => {
    Isolated(() => {
      $XDG_DATA_HOME = ''
      spec.Expect(config.Load().log_file).ToEqual(DefaultLogFile())
    })
  })

  spec.It('expands a tilde in a configured log file', () => {
    Isolated(() => {
      g:keyhabits_log_file = '~/logs/keys.jsonl'
      spec.Expect(config.Load().log_file).ToEqual(expand('~/logs/keys.jsonl'))
    })
  })

  spec.It('reads the current options on every call', () => {
    Isolated(() => {
      g:keyhabits_report_limit = 5
      spec.Expect(config.Load().report_limit).ToEqual(5)
      g:keyhabits_report_limit = 7
      spec.Expect(config.Load().report_limit).ToEqual(7)
    })
  })
})
