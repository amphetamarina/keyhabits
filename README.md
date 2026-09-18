# keyhabits

keyhabits is a Vim 9 plugin that watches every key you press, remembers the
mode it was pressed in, and turns that stream into a report of your most
repeated keystrokes and commands. Recording is cheap: keys are buffered in
memory and flushed to disk in batches. The log is a plain append-only JSONL
file, and printable text typed in Insert, Replace and Command-line modes is
redacted to `<text>` by default so that counts and rhythm survive while
content does not. It is written entirely in Vim9script and has no external
dependencies.

Status: in development.

## Requirements

- Vim 9.1.0564 or newer (`KeyInputPre`, `SafeState`, Vim9
  `class`/`interface`). Vim 9.2 is what the test suite runs against.

## Planned commands

- `:KeyHabitsStart` — begin recording
- `:KeyHabitsStop` — flush and stop recording
- `:KeyHabitsReport [days]` — open a report, optionally limited to the last
  `<days>` days
- `:KeyHabitsClear` — delete the log after a confirmation prompt

Recording starts automatically on startup unless `g:keyhabits_auto_start` is
set to `0`. See `docs/ARCHITECTURE.md` for the full design and
`docs/BACKLOG.md` for the task list.

