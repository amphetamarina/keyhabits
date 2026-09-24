# keyhabits — Architecture

`keyhabits` is a Vim 9 plugin that records every key you press (with its mode),
persists the stream to disk, and generates a report of your most repeated
keystrokes and commands. It is written entirely in Vim9script and has no
external dependencies.

Requirements: Vim 9.1.0564 or newer (needs `KeyInputPre`, `SafeState`, and
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
    advice.vim                        tip catalogue + matcher over command runs
  app/
    store.vim                         `interface EventStore`
    recorder.vim                      use case: buffer events, flush to a store
    reporter.vim                      use case: events -> Report data structure
    notifier.vim                      `interface Notifier`
    coach.vim                         use case: live tips from recent commands
  infra/
    memory_store.vim                  EventStore kept in memory (tests, dry runs)
    jsonl_store.vim                   EventStore backed by an append-only JSONL file
    capture.vim                       KeyInputPre/SafeState autocmds -> recorder
    report_buffer.vim                 renders a Report into a scratch buffer
    popup_notifier.vim                Notifier shown with popup_notification()
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
| `typed` | string | `v:event.typedchar`; the key the user physically typed.    |
|         |        | Statistics count `typed`, because it is the habit; `key`   |
|         |        | only says what a mapping expanded to                       |
| `ft`    | string | `&filetype` of the current buffer                          |

Only key presses with a non-empty `typedchar` are recorded. Vim raises
`KeyInputPre` again for keys it generates itself (`x` is executed as `dl`, a
mapping replays its right-hand side) and those carry an empty `typedchar`;
they are not habits and are dropped by capture.

`event.vim` exports `New(...)`, `Encode(event): string` (JSON line) and
`Decode(line: string): dict<any>`. `Decode` must reject malformed lines by
throwing, never by returning partial data.

### Privacy rule

In Insert, Replace, Command-line and Terminal modes the printable characters
user's actual text (and could include passwords). By default those are
recorded as the placeholder key `<text>` so counts and rhythm survive but
content does not. Special keys (`<Esc>`, `<C-w>`, `<CR>`, arrows) are always
recorded verbatim. Setting `g:keyhabits_record_text = 1` records everything.
This redaction is a domain rule and lives in `event.vim`, not in capture.

### Stats

`stats.vim` is pure: it takes `list<dict<any>>` and returns plain data.

- `CountKeys(events)` -> `dict<number>` keyed by `typed`
- `CountModes(events)` -> `dict<number>` keyed by `mode`
- `CountFiletypes(events)`
- `GroupCommands(events)` -> `list<string>`; joins the `typed` keys of each
  `(sid, grp)` in order into one string, e.g. `"ciw<text><Esc>"`, `"3dd"`.
  Only groups whose first key is in Normal or Visual mode count as commands.
  A run of consecutive `<text>` placeholders collapses into one, so
  `i<text><text><text><Esc>` and `i<text><Esc>` are the same habit.
- `CountCommands(events)` -> `dict<number>` over `GroupCommands`
- `Ngrams(keys: list<string>, n: number)` -> `dict<number>`; sliding window,
  never crossing a session boundary
- `Top(counts: dict<number>, limit: number)` -> `list<list<any>>` of
  `[key, count]` sorted by count desc, then key asc for determinism

### Advice

`advice.vim` holds the rule catalogue and is pure. A rule is a plain dict:

| field      | type         | meaning                                           |
|------------|--------------|---------------------------------------------------|
| `id`       | string       | stable name, e.g. `repeated-j`                    |
| `sequence` | list<string> | regexes, each matched against one whole command,  |
|            |              | in order, e.g. `['^\$$', '^a\%(<text>\)\=<Esc>$']` |
| `min`      | number       | times in a row the sequence must occur; a rule    |
|            |              | with `min` 1 matches one occurrence at a time     |
| `fix`      | number       | keys the better way takes, typed text not counted |
| `tip`      | string       | the better way, one short line                    |
| `help`     | string       | a `:help` tag that is the source of the tip       |

Rules match runs of consecutive commands, not single command strings:
`SafeState` ends a group after every plain motion, so `jjjj` is four `j`
commands. Tips come only from Vim's own help (the user manual `usr_*.txt`
and the reference manual); every `help` tag must resolve with
`getcompletion(tag, 'help')`, and a spec enforces it.

- `Rules()` -> `list<dict<any>>`
- `KeyCount(command)` -> keys typed for a command; `<text>` counts as none,
  a named key such as `<Esc>` as one
- `Match(commands: list<string>, rules)` -> `dict<dict<number>>` of
  `{id: {runs, saved}}`. At each position the first matching rule wins and
  its run is consumed, so a run is counted once; `saved` adds up the keys of
  each run minus `fix`

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
  advice:          [{tip, help, runs, saved}, ...],
}
```

Advice is matched per session and ranked by `saved`; rows that save nothing
are left out.

`options`: `{limit: number, since: number}` where `since` is a `ts` lower
bound (0 = everything).

### Coach

Live nudges. Keeps the finished commands of the last `window` seconds, runs
`advice.Match` on each new one and, when a rule reaches `threshold`
occurrences in the window and is outside its `cooldown`, calls
`notifier.Notify(rule)` and restarts that rule's cooldown. It shows at most
one tip per command. The time arrives with each command,
`Observe(command, now)`, and the `Notifier` interface (`app/notifier.vim`) is
injected, so the coach is tested without clocks or popups. The window is
also capped at 200 commands, because matching runs after every command.

The composition root wires the coach to `Capture.OnCommand()` only when
`g:keyhabits_nudge` is set, and skips commands while a macro is being
recorded or replayed (`reg_recording()`, `reg_executing()`): that repetition
is deliberate.

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
- Command boundaries, each calling `NextGroup()`:
  - `ModeChanged *:n*` when the new mode is Normal proper (`n`, not
    `no` operator-pending): fires when an operator finishes (`no>n`), when
    Insert or Replace ends (`i>n`), when a command line is done (`c>n`), and
    when Visual ends (`v>n`). This makes `ciw<text><Esc>`, `3dd`, `x` and
    `:<text><CR>` single commands.
  - `SafeState *` only while `mode(1)` starts with `n`: separates plain
    motions such as `j`, `w`, `p`, `u` and `.` that change no mode. It is
    ignored in other modes, where it fires after every key and would fragment
    a command. It also does not fire while typeahead is pending (a fast
    `<Esc>` followed by a key), which is why `ModeChanged` is the primary
    boundary.
- `OnCommand(listener)` registers a `func(string)` that receives each
  finished command, e.g. `ciw<text><Esc>`. The keys of the current command
  are kept only while a listener is set, and turned into the command with
  `stats.GroupCommands` at the next boundary.
- `VimLeavePre *` -> `recorder.Flush()`.
- A `timer_start` every `g:keyhabits_flush_interval` ms -> `recorder.Flush()`.

`Start()` and `Stop()` are idempotent. `Stop()` flushes, deletes the augroup
and stops the timer.

### Popup notifier

Implements `Notifier` with `popup_notification()`: a small popup in the top
right that closes on its own after a few seconds and never takes focus or
input. It shows the tip and its `:help` tag.

### Report buffer

Opens a new scratch buffer (`buftype=nofile bufhidden=wipe noswapfile`,
filetype `keyhabits-report`) and writes the Report as aligned text sections.
Pure rendering: a `Render(report): list<string>` function that is unit-tested,
plus a thin `Open(lines)` that creates the buffer. Mode rows are shown
with readable labels (`n` and `no` are both Normal); rows that share a label
are merged and re-sorted before rendering.

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
| `g:keyhabits_nudge`             | `0`; `1` shows live tips                     |
| `g:keyhabits_nudge_threshold`   | `3` matches of one rule within the window    |
| `g:keyhabits_nudge_window`      | `60` seconds                                 |
| `g:keyhabits_nudge_cooldown`    | `600` seconds before the same tip again      |

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
