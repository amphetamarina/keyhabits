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
- [x] T13 Live nudges: capture hands each finished command to
          `app/coach.vim`, which applies the threshold and cooldowns and calls
          a `Notifier`; `infra/popup_notifier.vim` shows the tip with
          `popup_notification()`. Options `g:keyhabits_nudge`,
          `g:keyhabits_nudge_threshold`, `g:keyhabits_nudge_window`,
          `g:keyhabits_nudge_cooldown`. Specs use a fake notifier and clock.

T1 to T13 built the Vim 9 version, kept on the `legacy-vim9` branch. From
T14 on the plugin is Lua for Neovim and LazyVim.

- [x] T14 Port to Lua: domain (event, stats, advice matcher, tip catalogue),
          app (recorder, reporter, coach) and infra (capture with
          `vim.on_key`, JSONL store, report float, `vim.notify` notifier),
          `setup(opts)`, `:KeyHabits` and specs run in `nvim --headless`.
          The log format and path stay the same, so history carries over.
- [x] T15 Aware of the editor: `app/selection.lua` hides a tip whose key the
          config maps to something else (LazyVim's `s`, `H`, `L`), swaps in a
          plugin's better version (flash.nvim), and leaves out tips whose
          plugin is missing (mini.ai). Capture ignores keys which-key and
          mini.ai report twice. `:KeyHabits tips`, `:KeyHabits why`,
          `:checkhealth keyhabits`, and a toggle for LazyVim's `<leader>u`.
- [x] T16 LazyVim and Neovim tips: `needs_mapping` and `source` let a tip or
          variant depend on a mapping (LazyVim's `<C-J>`, `<A-j>`, flash's
          `<C-S>` search toggle); seven tips use them and Neovim's
          `]<Space>`. Notifications wrap to the notifier's width. Capture
          recognises which-key replaying a command key by key.
- [x] T17 Stats only: the tips, the live coach, the tip selection and the
          notifier are removed at the maintainer's request; the plugin
          records and reports. The last commit with tips is `aa48c57`.
