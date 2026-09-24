# keyhabits — Architecture

`keyhabits` is a Neovim plugin that records every key you press (with its
mode), persists the stream to disk, reports your most repeated keystrokes and
commands, and shows a tip the moment a habit has a better command. It is
written in Lua for Neovim 0.11+ and LazyVim, with no required dependencies.
The Vim 9 version is on the `legacy-vim9` branch.

## Layers (Clean Architecture)

Dependencies point inward only. Nothing in `domain/` requires `app/` or
`infra/`. Nothing in `app/` requires `infra/`. `init.lua` is the composition
root that wires concrete infrastructure into use cases.

```
plugin/keyhabits.lua                  defines :KeyHabits
lua/keyhabits/
  init.lua                            composition root: setup(opts), public API
  config.lua                          defaults, merge and validation
  health.lua                          :checkhealth keyhabits
  domain/
    event.lua                         Event value object, redaction, JSON
    stats.lua                         pure aggregation over lists of events
    advice.lua                        matcher of tips over command runs
    tips.lua                          the tip catalogue (data)
  app/
    recorder.lua                      use case: buffer events, flush to a store
    reporter.lua                      use case: events -> Report
    coach.lua                         use case: live tips from recent commands
    selection.lua                     which tips apply in this editor
  infra/
    capture.lua                       vim.on_key + ModeChanged/SafeState -> recorder
    jsonl_store.lua                   store backed by an append-only JSONL file
    memory_store.lua                  store kept in memory (specs)
    environment.lua                   installed plugins, remapped keys
    notifier.lua                      shows a tip with vim.notify()
    report_view.lua                   renders a Report into a float
doc/keyhabits.txt                     :help keyhabits
tests/
  spec.lua                            tiny BDD DSL (describe / it / expect)
  run.lua                             runs tests/*_spec.lua, sets the exit code
  *_spec.lua                          specs
```

## Domain

### Event

One key press, a plain table so it encodes to JSON as is:

| field   | type   | meaning                                                    |
|---------|--------|------------------------------------------------------------|
| `ts`    | number | `os.time()` when the key was seen                          |
| `sid`   | string | session id, `<pid>-<start time>`; groups keys per run      |
| `grp`   | number | command group, advanced at every command boundary          |
| `mode`  | string | `nvim_get_mode().mode` at the time of the key              |
| `key`   | string | the key after mappings                                     |
| `typed` | string | the key(s) physically typed; statistics count this         |
| `ft`    | string | `'filetype'` of the current buffer                         |

The format is the Vim version's, so one log serves both and history carries
over. `event.new(raw, record_text)` names keys with `keytrans()`;
`event.decode(line)` throws on a malformed line rather than return part of it.

### Privacy rule

In Insert, Replace, Command-line and Terminal modes, printable characters are
the user's text and could include passwords. They are stored as `<text>`; a
mapping's left-hand side that arrives as several printable characters is
masked the same way. Special keys are stored as they are. With `record_text`
everything is stored. The rule lives in `event.lua` and runs on the raw key,
before `keytrans()` makes `<` and space look like special keys.

### Stats

`stats.lua` is pure: `count_keys`, `count_modes`, `count_filetypes`,
`group_commands` (joins each group's typed keys into a command such as
`ciw<text><Esc>`, keeping groups that start in Normal or Visual mode and
collapsing runs of `<text>`), `count_commands`, `sessions` (events per session,
gathered even when two editors interleave in the log), `ngrams`,
`key_sequences` and `top` (sorted by count, then name).

### Tips and the matcher

`tips.lua` is data: one table per tip. Its header documents every field:
`sequence` (Vim regexes, one per command), `min`, `same`, `inside`, `repeats`,
`fix`/`fix_each` or `saves`, `tip`, `help`, `suggests`, `requires`,
`needs_mapping`, `source`, `variants` and `example`. Tips match runs of commands, because `SafeState` ends a command
after every plain motion, so `jjjj` is four `j` commands. They are tried in
order and the first match wins, so a longer habit comes before a shorter one
that starts the same way.

`advice.lua` matches them: `match(commands, tips)` returns `{ id = { runs,
saved } }`, consuming each run so it counts once; `uncovered(commands, tips)`
returns runs of three or more of a command no tip looks at; `key_count`
counts a command's keys with typed text left out. Regexes are compiled once,
and the tips that can start at each distinct command are remembered per tip
list, so matching after every key costs about 0.05 ms.

Specs check every tip: its help tag exists in Neovim's help (for tips that need
no plugin), it states its saving in exactly one way, and its `example` is
matched by that tip, before any other, saving at least one key.

## Application

### Recorder

Buffers events and appends them to a store (any table with `append`,
`read_all`, `clear`) when the buffer reaches the flush threshold, or on
`flush()`.

### Selection

Decides which tips apply in this editor, given an environment answering
`has(plugin)`, `mapped(mode, key)`, `remapped(mode, key)` and `disabled`:

1. a tip switched off in `setup()` is left out;
2. a tip whose `requires` plugin is missing is left out, and so is one whose
   `needs_mapping` key is not mapped (LazyVim's `<C-J>` or `<A-j>`);
3. the first variant whose plugin and mapping are there replaces the tip's
   text, help and suggested keys, and marks its `source`;
4. a tip whose suggested key is mapped to something else is left out, with
   the mapping's description as the reason.

`resolve(tip, env)` returns the tip as shown or `nil, reason`; `split` does a
whole catalogue.

### Reporter

`build(events, { limit, since, tips, resolve })` returns

```
{
  total_keys, sessions, time_span = { first, last },
  advice      = { { id, tip, help, source, runs, saved }, ... },
  untipped    = { { command, presses }, ... },
  top_keys, top_commands, top_bigrams, modes, filetypes = { { name, count }, ... },
}
```

Advice is matched per session, shown only for tips that resolve here, and
ranked by keys saved; `untipped` makes gaps in the catalogue visible.

### Coach

Keeps the finished commands of the last `window` seconds (at most 50), matches
them after each command and hands the first due tip, in catalogue order, to the
notifier: due means it reached `threshold` runs, is out of its `cooldown`, and
resolves here. Resolving at that moment means mappings made after startup
count. Time arrives with each command and the notifier is any table with
`notify(tip)`, so the coach is tested without clocks or UI.

## Infrastructure

### Capture

- `vim.on_key` gives the key after mappings and the key(s) typed. Keys with
  nothing typed (made by mappings or by Neovim) are dropped.
- Plugins that read keys themselves make Neovim report some twice: which-key
  feeds keys back (`dw` reports `w` twice; `<Space>ul` reports the three keys
  and then `<Space>ul`; `<C-W>j` reports `<C-W>` and `j` again one by one),
  and mini.ai's `i` reports `iw` after `i`. `new_part()` keeps only what a
  report adds to the keys already recorded for the command; a repeat of the
  last keys, or of the command from its first key, within 5 ms is a replay.
- Command boundaries: `ModeChanged` into Normal proper, and `SafeState` while
  in Normal mode, which separates plain motions.
- `VimLeavePre` and a `vim.uv` timer flush the recorder.

### Environment

`has(plugin)` asks lazy.nvim, then `package.loaded`, then the runtime path.
`remapped(mode, key)` reports a mapping that has a description and does not
simply run the key: LazyVim's `s` (Flash) and `H` (Prev Buffer) count, its
`j` (`v:count == 0 ? 'gj' : 'j'`) and flash's `f` (no description) do not.

### Notifier and report view

The notifier calls `vim.notify()` with the title `keyhabits`, which LazyVim
routes to noice or snacks, and remembers the last tip for `:KeyHabits why`.
snacks makes a notification at most 40% of the screen wide and cuts longer
lines, so the notifier wraps the tip at word boundaries to that width and puts
the source and `:help` on the last line.
The report opens in a centred float; `q` closes it and `<CR>` on an Advice
line opens the tip's help.

## Commands and options

`:KeyHabits [report [days] | start | stop | clear[!] | why | tips | toggle]`,
completed; with no argument, the report. `require("keyhabits")` exposes the
same as functions, plus `last_tip()`, `is_recording()` and `tips_enabled()`.

Options, with defaults, are documented in `config.lua` and `:help keyhabits`.

## Testing

`make test` runs `nvim --headless --clean -l tests/run.lua`. The live path is
verified by running the real LazyVim config in a pseudo-terminal and feeding
keys from a timer, since headless Neovim never fires `SafeState`.
