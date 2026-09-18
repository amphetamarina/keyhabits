vim9script

# Specs for the Event domain module: construction, privacy redaction and the
# JSON round trip.

import './spec.vim' as spec
import autoload 'keyhabits/domain/event.vim'

def Raw(overrides: dict<any>): dict<any>
  return extend({
    ts: 1700000000,
    sid: '1234-1700000000',
    grp: 7,
    mode: 'n',
    key: 'j',
    typed: '',
    ft: 'vim',
  }, overrides)
enddef

def RawJson(overrides: dict<any>): string
  return json_encode(Raw(overrides))
enddef

spec.Describe('event.New', () => {
  spec.It('builds exactly the seven documented fields', () => {
    var built: dict<any> = event.New(Raw({}))
    spec.Expect(sort(keys(built))).ToEqual(
      ['ft', 'grp', 'key', 'mode', 'sid', 'ts', 'typed'])
    spec.Expect(built.ts).ToEqual(1700000000)
    spec.Expect(built.sid).ToEqual('1234-1700000000')
    spec.Expect(built.grp).ToEqual(7)
    spec.Expect(built.mode).ToEqual('n')
    spec.Expect(built.key).ToEqual('j')
    spec.Expect(built.typed).ToEqual('')
    spec.Expect(built.ft).ToEqual('vim')
  })

  spec.It('names special keys with keytrans', () => {
    spec.Expect(event.New(Raw({key: "\<Esc>"})).key).ToEqual('<Esc>')
    spec.Expect(event.New(Raw({key: "\<Up>"})).key).ToEqual('<Up>')
    spec.Expect(event.New(Raw({key: "\<C-W>"})).key).ToEqual('<C-W>')
    spec.Expect(event.New(Raw({key: "\<Tab>"})).key).ToEqual('<Tab>')
    spec.Expect(event.New(Raw({key: ' '})).key).ToEqual('<Space>')
    spec.Expect(event.New(Raw({key: '<'})).key).ToEqual('<lt>')
    spec.Expect(event.New(Raw({key: 'j'})).key).ToEqual('j')
    spec.Expect(event.New(Raw({key: 'é'})).key).ToEqual('é')
  })

  spec.It('converts typed the same way', () => {
    spec.Expect(event.New(Raw({typed: "\<Esc>"})).typed).ToEqual('<Esc>')
    spec.Expect(event.New(Raw({typed: 'j'})).typed).ToEqual('j')
  })

  spec.It('redacts text typed in insert mode', () => {
    for ch in ['a', ' ', '<', 'é']
      var built: dict<any> = event.New(Raw({mode: 'i', key: ch, typed: ch}))
      spec.Expect(built.key).ToEqual('<text>')
      spec.Expect(built.typed).ToEqual('<text>')
    endfor
  })

  spec.It('keeps special keys in insert mode', () => {
    var special_keys: list<list<string>> = [
      ["\<Esc>", '<Esc>'],
      ["\<C-W>", '<C-W>'],
      ["\<BS>", '<BS>'],
      ["\<Tab>", '<Tab>'],
      ["\<CR>", '<CR>'],
    ]
    for [key, name] in special_keys
      var built: dict<any> = event.New(Raw({mode: 'i', key: key, typed: key}))
      spec.Expect(built.key).ToEqual(name)
      spec.Expect(built.typed).ToEqual(name)
    endfor
  })

  spec.It('redacts text in command-line, replace and terminal modes', () => {
    var in_cmdline: dict<any> = event.New(Raw({mode: 'c', key: 'x', typed: 'x'}))
    var in_replace: dict<any> = event.New(Raw({mode: 'R', key: 'x', typed: 'x'}))
    var in_terminal: dict<any> = event.New(Raw({mode: 't', key: 'x', typed: 'x'}))
    spec.Expect(in_cmdline.key).ToEqual('<text>')
    spec.Expect(in_cmdline.typed).ToEqual('<text>')
    spec.Expect(in_replace.key).ToEqual('<text>')
    spec.Expect(in_replace.typed).ToEqual('<text>')
    spec.Expect(in_terminal.key).ToEqual('<text>')
    spec.Expect(in_terminal.typed).ToEqual('<text>')
  })

  spec.It('never redacts normal mode text', () => {
    var built: dict<any> = event.New(Raw({mode: 'n', key: 'a', typed: 'a'}))
    spec.Expect(built.key).ToEqual('a')
    spec.Expect(built.typed).ToEqual('a')
  })

  spec.It('leaves an empty typed string empty', () => {
    spec.Expect(event.New(Raw({mode: 'i', typed: ''})).typed).ToEqual('')
  })

  spec.It('records text verbatim when record_text is true', () => {
    var built: dict<any> = event.New(Raw({mode: 'i', key: 'a', typed: 'a'}), true)
    spec.Expect(built.key).ToEqual('a')
    spec.Expect(built.typed).ToEqual('a')
  })
})

spec.Describe('event.Redact', () => {
  spec.It('replaces printable text in a text mode with the placeholder', () => {
    for ch in ['a', ' ', '<', 'é']
      var redacted: dict<any> = event.Redact(Raw({mode: 'i', key: ch, typed: ch}))
      spec.Expect(redacted.key).ToEqual('<text>')
      spec.Expect(redacted.typed).ToEqual('<text>')
    endfor
  })

  spec.It('replaces printable text in terminal mode with the placeholder', () => {
    var redacted: dict<any> = event.Redact(Raw({mode: 't', key: 'a', typed: 'a'}))
    spec.Expect(redacted.key).ToEqual('<text>')
    spec.Expect(redacted.typed).ToEqual('<text>')
  })

  spec.It('keeps special keys', () => {
    for key in ["\<Esc>", "\<C-W>", "\<BS>", "\<Tab>", "\<CR>"]
      var redacted: dict<any> = event.Redact(Raw({mode: 'i', key: key, typed: key}))
      spec.Expect(redacted.key).ToEqual(key)
      spec.Expect(redacted.typed).ToEqual(key)
    endfor
  })

  spec.It('leaves normal mode keys alone', () => {
    var redacted: dict<any> = event.Redact(Raw({mode: 'n', key: 'a', typed: 'a'}))
    spec.Expect(redacted.key).ToEqual('a')
    spec.Expect(redacted.typed).ToEqual('a')
  })

  spec.It('does not mutate its input', () => {
    var original: dict<any> = Raw({mode: 'i', key: 'a', typed: 'a'})
    var redacted: dict<any> = event.Redact(original)
    spec.Expect(redacted.key).ToEqual('<text>')
    spec.Expect(original.key).ToEqual('a')
    spec.Expect(original.typed).ToEqual('a')
  })
})

spec.Describe('event.Encode and event.Decode', () => {
  spec.It('round trips an event', () => {
    var built: dict<any> = event.New(Raw({mode: 'i', key: "\<Esc>", typed: 'a'}))
    spec.Expect(event.Decode(event.Encode(built))).ToEqual(built)
  })

  spec.It('encodes one line without a newline', () => {
    var encoded: string = event.Encode(event.New(Raw({})))
    spec.Expect(stridx(encoded, "\n")).ToEqual(-1)
    spec.Expect(encoded).ToContain('"key":"j"')
  })

  spec.It('rejects invalid JSON', () => {
    spec.Expect(() => event.Decode('garbage')).ToThrow('^keyhabits.event: ')
  })

  spec.It('rejects a JSON value that is not an object', () => {
    spec.Expect(() => event.Decode('[1, 2]')).ToThrow('^keyhabits.event: ')
  })

  spec.It('rejects a missing field', () => {
    var raw_dict: dict<any> = Raw({})
    remove(raw_dict, 'ft')
    spec.Expect(() => event.Decode(json_encode(raw_dict))).ToThrow('missing field ft')
  })

  spec.It('rejects a field of the wrong type', () => {
    var encoded: string = RawJson({ts: '1700000000'})
    spec.Expect(() => event.Decode(encoded)).ToThrow('field ts must be a number but is a string')
  })

  spec.It('rejects an unknown field', () => {
    var encoded: string = RawJson({extra: 1})
    spec.Expect(() => event.Decode(encoded)).ToThrow('unknown field extra')
  })
})
