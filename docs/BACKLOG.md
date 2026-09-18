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
- [ ] T6  `app/recorder.vim` + spec (threshold flush, manual flush, no-op flush).
- [ ] T7  `config.vim` + spec (defaults, overrides, XDG path).
- [ ] T8  `infra/capture.vim` + `plugin/keyhabits.vim` (Start/Stop/Clear
          commands, auto-start, timer). Integration spec using `feedkeys()`.
- [ ] T9  `app/reporter.vim` + `infra/report_buffer.vim` + `:KeyHabitsReport`
          + specs (Build, Render).
- [ ] T10 `doc/keyhabits.txt` help file and a complete README.
