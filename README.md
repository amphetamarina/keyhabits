# keyhabits

keyhabits is a Vim 9 plugin that watches every key you press, remembers the
mode it was pressed in, and turns that stream into a report of your most
repeated keystrokes and commands. Recording is cheap: keys are buffered in
memory and flushed to disk in batches. The log is a plain append-only JSONL
file, and printable text typed in Insert, Replace, Command-line and Terminal
modes is redacted to `<text>` by default so that counts and rhythm survive
while content does not. It is written entirely in Vim9script and has no
external dependencies.

## Requirements

- Vim 9.1.0564 or newer. `KeyInputPre` arrived in patch 9.1.0563 and
  `v:event.typedchar` in 9.1.0564, which is what lets keyhabits tell the keys
  you typed from the keys Vim generates itself.

## Installation

With Vim's native package support:

    git clone https://github.com/amphetamarina/keyhabits ~/.vim/pack/plugins/start/keyhabits
    :helptags ~/.vim/pack/plugins/start/keyhabits/doc

With vim-plug:

    Plug 'amphetamarina/keyhabits'

## Quick start

Recording starts automatically when Vim starts. After using Vim for a while:

    :KeyHabitsReport      " report on everything in the log
    :KeyHabitsReport 7    " report on the last seven days

## Commands

| command | effect |
|---------|--------|
| `:KeyHabitsStart` | start recording; does nothing if already recording |
| `:KeyHabitsStop` | flush what is buffered and stop recording |
| `:KeyHabitsReport [days]` | open a report, optionally limited to the last `<days>` days |
| `:KeyHabitsClear[!]` | delete the log after a confirmation prompt; `[!]` skips the question |

## Options

| variable | default | meaning |
|----------|---------|---------|
| `g:keyhabits_log_file` | `$XDG_DATA_HOME/keyhabits/events.jsonl`, else `~/.local/share/keyhabits/events.jsonl` | where events are appended |
| `g:keyhabits_auto_start` | `1` | start recording on `VimEnter` |
| `g:keyhabits_flush_threshold` | `200` | events buffered before they are written |
| `g:keyhabits_flush_interval` | `30000` | milliseconds between flushes of a partial buffer; `0` disables the timer |
| `g:keyhabits_record_text` | `0` | record typed text instead of `<text>` |
| `g:keyhabits_report_limit` | `20` | entries shown per ranked report section |
| `g:keyhabits_nudge` | `0` | `1` shows a tip in a popup while you work |
| `g:keyhabits_nudge_threshold` | `1` | times a habit must occur within the window before its tip shows; a run such as `jjjj` counts once |
| `g:keyhabits_nudge_window` | `60` | seconds of recent commands watched |
| `g:keyhabits_nudge_cooldown` | `600` | seconds before the same tip may show again |

## Privacy

In Insert, Replace, Command-line and Terminal modes the printable characters
are the text you are entering, which can include passwords. By default each
such character is stored as the placeholder `<text>`, so counts and rhythm
survive while the content does not; the report collapses a run of them into
one. Special keys such as `<Esc>`, `<C-w>` and `<CR>` are always stored as they
are.

**Warning:** with `g:keyhabits_record_text` set to `1`, the log contains
everything you type, including passwords, in clear text.

## How commands are grouped

A command starts in Normal mode and ends when you return to Normal: `ciw`, the
text you type and the closing `<Esc>` are one command, with the typed text
collapsed to a single `<text>`. Plain Normal-mode motions are separated by
`SafeState`, and key pairs are counted within one session, so no pair spans two
Vim runs.

## Advice

The report opens with advice: habits that a better command would replace, such
as repeating `j` where a count would do, or `$a` where `A` would. Each tip is
ranked by the keys it would have saved and names the `:help` topic it comes
from. Tips are taken only from Vim's own documentation, and a spec fails if any
cited help tag does not exist.

With `let g:keyhabits_nudge = 1` the same tips also appear live, in a small
popup in the top right corner, the moment a habit happens, for example on the
fourth `j` in a row. The popup closes by itself and never takes focus; each
tip waits ten minutes before it can show again, and macros are never coached.

## Development

`make test` runs every spec through `test/run.vim` and exits non-zero on any
failure. The code is layered as described in `docs/ARCHITECTURE.md`: domain
value objects and statistics, application use cases, infrastructure adapters
and a plugin that wires them together. `AGENTS.md` has the conventions, the
commit message format and the headless Vim rules.

See `doc/keyhabits.txt` for the user documentation, reachable as `:help
keyhabits`.
