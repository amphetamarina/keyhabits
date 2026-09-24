# Backlog

Each task is one reviewable unit and should land as one or a few atomic
commits. Order matters: later tasks build on earlier ones. A task is done when
its tests pass under `make test` and the lead has approved the diff.

- [x] T1  Scaffold: `AGENTS.md`, `README.md`, `.gitignore`, `.editorconfig`,
          commit `docs/ARCHITECTURE.md` and this backlog.
- [x] T2  Test harness: `test/spec.vim`, `test/run.vim`, `Makefile`, and a
          `spec_spec.vim` that proves passing and failing expectations are
          reported correctly.
- [x] T3  `domain/event.vim` + spec (New, Encode, Decode, privacy redaction).
- [x] T4  `domain/stats.vim` + spec (all pure aggregation functions).
- [x] T5  `app/store.vim` interface, `infra/memory_store.vim`,
          `infra/jsonl_store.vim` + specs (append, read, corrupt line, clear).
- [x] T6  `app/recorder.vim` + spec (threshold flush, manual flush, no-op flush).
- [x] T7  `config.vim` + spec (defaults, overrides, XDG path).
- [x] T8  `infra/capture.vim` + `plugin/keyhabits.vim` (Start/Stop/Clear
          commands, auto-start, timer). Integration spec using `feedkeys()`.
- [x] T9  `app/reporter.vim` + `infra/report_buffer.vim` + `:KeyHabitsReport`
          + specs (Build, Render).
- [x] T10 `doc/keyhabits.txt` help file and a complete README.
- [x] T11 Command boundaries and physical keys: `ModeChanged` plus a guarded
          `SafeState`, drop keys Vim generates itself, count `typed`, collapse
          insert text, merge mode rows.
- [x] T12 `domain/advice.vim` + spec: the rule catalogue and a pure matcher
          over a list of commands. Every rule cites a `:help` tag, and a spec
          fails if `getcompletion(tag, 'help')` has no exact match. Add an
          "Advice" section to the report, ranked by occurrences times keys
          saved.
- [ ] T13 Live nudges: capture hands each finished command to
          `app/coach.vim`, which applies the threshold and cooldowns and calls
          a `Notifier`; `infra/popup_notifier.vim` shows the tip with
          `popup_notification()`. Options `g:keyhabits_nudge`,
          `g:keyhabits_nudge_threshold`, `g:keyhabits_nudge_window`,
          `g:keyhabits_nudge_cooldown`. Specs use a fake notifier and clock.
