# keyhabits — Architecture

`keyhabits` is a Vim 9 plugin that records every key you press (with its mode),
persists the stream to disk, and generates a report of your most repeated
keystrokes and commands. It is written entirely in Vim9script and has no
external dependencies.

Requirements: Vim 9.1.0034 or newer (needs `KeyInputPre`, `SafeState`, and
Vim9 `class`/`interface`).

## Layers (Clean Architecture)

Dependencies point inward only. Nothing in `domain/` imports from `app/` or
`infra/`. Nothing in `app/` imports from `infra/`. `plugin/keyhabits.vim` is
the composition root that wires concrete infrastructure into use cases.

```
plugin/keyhabits.vim                  composition root: commands, auto-start
autoload/keyhabits/
  config.vim                          reads g:keyhabits_* with defaults
  domain/
    event.vim                         Event value object + (de)serialization
    stats.vim                         pure aggregation over lists of events
  app/
    store.vim                         `interface EventStore`
    recorder.vim                      use case: buffer events, flush to a store
    reporter.vim                      use case: events -> Report data structure
  infra/
    memory_store.vim                  EventStore kept in memory (tests, dry runs)
    jsonl_store.vim                   EventStore backed by an append-only JSONL file
    capture.vim                       KeyInputPre/SafeState autocmds -> recorder
    report_buffer.vim                 renders a Report into a scratch buffer
doc/keyhabits.txt                     Vim help
test/
  spec.vim                            tiny BDD DSL (Describe / It / Expect)
  run.vim                             discovers *_spec.vim, runs, sets exit code
  *_spec.vim                          one spec file per module
```

## Domain

### Event

One key press. Represented as `dict<any>` so it can be serialized with
`json_encode()` without conversion.

| field   | type   | meaning                                                    |
|---------|--------|------------------------------------------------------------|
| `ts`    | number | `localtime()` when the key was seen                        |
| `sid`   | string | session id, `<pid>-<start time>`; groups keys per Vim run  |
| `grp`   | number | command group. Incremented by `SafeState`. Keys sharing a  |
|         |        | `(sid, grp)` were typed as one command, e.g. `c`,`i`,`w`   |
| `mode`  | string | `mode(1)` at the time of the key                           |
| `key`   | string | `v:char` after mappings; the key Vim actually processed    |
| `typed` | string | `v:event.typedchar`; what the user physically typed        |
| `ft`    | string | `&filetype` of the current buffer                          |

`event.vim` exports `New(...)`, `Encode(event): string` (JSON line) and
`Decode(line: string): dict<any>`. `Decode` must reject malformed lines by
throwing, never by returning partial data.

### Privacy rule

In Insert, Replace and Command-line modes the printable characters are the
user's actual text (and could include passwords). By default those are
recorded as the placeholder key `<text>` so counts and rhythm survive but
content does not. Special keys (`<Esc>`, `<C-w>`, `<CR>`, arrows) are always
recorded verbatim. Setting `g:keyhabits_record_text = 1` records everything.
This redaction is a domain rule and lives in `event.vim`, not in capture.

### Stats

`stats.vim` is pure: it takes `list<dict<any>>` and returns plain data.

- `CountKeys(events)` -> `dict<number>` keyed by `key`
- `CountModes(events)` -> `dict<number>` keyed by `mode`
- `CountFiletypes(events)`
- `GroupCommands(events)` -> `list<string>`; joins `key`s of each
  `(sid, grp)` in order into one string, e.g. `"ciw"`, `"3dd"`, `"<text>"`.
  Only groups whose first key is in Normal or Visual mode count as commands.
- `CountCommands(events)` -> `dict<number>` over `GroupCommands`
- `Ngrams(keys: list<string>, n: number)` -> `dict<number>`; sliding window,
  never crossing a session boundary
- `Top(counts: dict<number>, limit: number)` -> `list<list<any>>` of
  `[key, count]` sorted by count desc, then key asc for determinism

## Application

### EventStore (interface)

```vim
export interface EventStore
  def Append(events: list<dict<any>>)
  def ReadAll(): list<dict<any>>
  def Clear()
endinterface
```

### Recorder

Holds an in-memory buffer of events. `Record(event)` appends to the buffer;
when the buffer reaches `flush_threshold` it calls `store.Append()` and empties
the buffer. `Flush()` forces this. The recorder never touches autocmds, timers
or files: it is fully testable with `MemoryStore`.

### Reporter

`Build(events, options): dict<any>` returns a `Report`:

```
{
  total_keys:      number,
  sessions:        number,
  time_span:       [first_ts, last_ts],
  top_keys:        [[key, count], ...],
  top_commands:    [[command, count], ...],
  top_bigrams:     [[keys, count], ...],
  modes:           [[mode, count], ...],
  filetypes:       [[ft, count], ...],
}
```

`options`: `{limit: number, since: number}` where `since` is a `ts` lower
bound (0 = everything).

## Infrastructure

### JsonlStore

One `json_encode`d event per line, appended with `writefile(lines, path, 'a')`.
`ReadAll()` decodes every line; a corrupt line is skipped and counted, never
fatal. Directory is created on first write (`mkdir(..., 'p')`).

### Capture

Registers, in augroup `keyhabits`:

- `KeyInputPre *` -> builds an Event via `event.New()` and calls
  `recorder.Record()`. Must be cheap: no file I/O, no string formatting beyond
  building the dict.
- `SafeState *` -> increments the command group counter.
- `VimLeavePre *` -> `recorder.Flush()`.
- A `timer_start` every `g:keyhabits_flush_interval` ms -> `recorder.Flush()`.

`Start()` and `Stop()` are idempotent. `Stop()` flushes, deletes the augroup
and stops the timer.

### Report buffer

Opens a new scratch buffer (`buftype=nofile bufhidden=wipe noswapfile`,
filetype `keyhabits-report`) and writes the Report as aligned text sections.
Pure rendering: a `Render(report): list<string>` function that is unit-tested,
plus a thin `Open(lines)` that creates the buffer.

## Commands and configuration

| command                       | effect                                             |
|-------------------------------|----------------------------------------------------|
| `:KeyHabitsStart`             | begin recording (auto on startup unless disabled)  |
| `:KeyHabitsStop`              | flush and stop recording                           |
| `:KeyHabitsReport [days]`     | open a report; optional lookback in days           |
| `:KeyHabitsClear`             | delete the log after `confirm()`                   |

| variable                        | default                                     |
|---------------------------------|---------------------------------------------|
| `g:keyhabits_log_file`          | `$XDG_DATA_HOME/keyhabits/events.jsonl` or `~/.local/share/keyhabits/events.jsonl` |
| `g:keyhabits_auto_start`        | `1`                                          |
| `g:keyhabits_flush_threshold`   | `200` events                                 |
| `g:keyhabits_flush_interval`    | `30000` ms                                   |
| `g:keyhabits_record_text`       | `0`                                          |
| `g:keyhabits_report_limit`      | `20`                                         |

## Testing

Tests are BDD specs written in Vim9script using `test/spec.vim`:

```vim
vim9script
import '../test/spec.vim' as spec
import autoload 'keyhabits/domain/stats.vim'

spec.Describe('stats.Top', () => {
  spec.It('sorts by count descending then key ascending', () => {
    spec.Expect(stats.Top({a: 2, b: 5, c: 2}, 2)).ToEqual([['b', 5], ['a', 2]])
  })
})
```

`make test` runs `vim -Nu NONE -es --not-a-term -S test/run.vim` and exits
non-zero on any failure. Tests must not depend on the user's vimrc, plugins
or the real log file; file-based specs use `tempname()`.
