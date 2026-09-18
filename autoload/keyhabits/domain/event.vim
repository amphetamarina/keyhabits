vim9script

# The Event value object: one key press.
#
# A recorded event has exactly seven fields. Keys are stored with readable
# names ("<Esc>", "<Space>") by keytrans(), and text typed in Insert, Replace
# and Command-line modes is replaced by a placeholder, so that counts and
# rhythm survive while content does not.

const placeholder: string = '<text>'

const field_types: dict<string> = {
  ts: 'number',
  sid: 'string',
  grp: 'number',
  mode: 'string',
  key: 'string',
  typed: 'string',
  ft: 'string',
}

def Problem(detail: string): string
  return 'keyhabits.event: ' .. detail
enddef

# Insert, Replace, Command-line and Terminal families of mode(1).
def IsTextMode(mode: string): bool
  return mode != '' && stridx('iRct', mode[0]) >= 0
enddef

# A single printable character is the user's text; anything else (Esc, Tab,
# CR, BS, arrows, Ctrl combinations) is a key to be kept verbatim.
def IsText(raw: string): bool
  return strcharlen(raw) == 1 && raw =~ '^[[:print:]]$'
enddef

def Mask(raw: string, mode: string): string
  return IsTextMode(mode) && IsText(raw) ? placeholder : raw
enddef

# The privacy rule at the raw level: key data in, key data out. It has to run
# before keytrans(), which would turn a typed '<' into '<lt>' and a space into
# '<Space>', making both indistinguishable from special keys.
export def Redact(event: dict<any>): dict<any>
  return {
    ts: event.ts,
    sid: event.sid,
    grp: event.grp,
    mode: event.mode,
    key: Mask(event.key, event.mode),
    typed: Mask(event.typed, event.mode),
    ft: event.ft,
  }
enddef

# keytrans() the raw key, unless Redact() already replaced it: the placeholder
# must not be translated ('<text>' would become '<lt>text>').
def KeyName(raw: string, masked: string): string
  return raw == masked ? keytrans(raw) : masked
enddef

export def New(raw: dict<any>, record_text: bool = false): dict<any>
  var masked: dict<any> = record_text ? raw : Redact(raw)
  return {
    ts: raw.ts,
    sid: raw.sid,
    grp: raw.grp,
    mode: raw.mode,
    key: KeyName(raw.key, masked.key),
    typed: KeyName(raw.typed, masked.typed),
    ft: raw.ft,
  }
enddef

export def Encode(event: dict<any>): string
  return json_encode(event)
enddef

export def Decode(line: string): dict<any>
  var decoded: any = v:none
  try
    decoded = json_decode(line)
  catch
    throw Problem($'not valid JSON: {v:exception}')
  endtry
  if type(decoded) != v:t_dict
    throw Problem($'expected a JSON object but got {typename(decoded)}')
  endif
  var event: dict<any> = decoded
  Validate(event)
  return event
enddef

def Validate(event: dict<any>)
  for [name, want] in items(field_types)
    if !has_key(event, name)
      throw Problem($'missing field {name}')
    endif
    var got: string = typename(event[name])
    if got != want
      throw Problem($'field {name} must be a {want} but is a {got}')
    endif
  endfor
  for name in keys(event)
    if !has_key(field_types, name)
      throw Problem($'unknown field {name}')
    endif
  endfor
enddef
