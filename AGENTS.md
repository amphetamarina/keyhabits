# Working on keyhabits

keyhabits is a Vim 9 plugin, written entirely in Vim9script, that records
every key press together with its mode and reports the most repeated
keystrokes and commands. It has no external dependencies.

`docs/ARCHITECTURE.md` is the source of truth for design and layering;
`docs/BACKLOG.md` is the source of truth for what to build next. Read both
before writing code. If something in them looks wrong, raise it with the
maintainer instead of silently deviating.

## Conventions

- Clean Code and Clean Architecture. Small functions, one responsibility,
  names that say what they do. No dead code, no commented-out code.
- Everything testable has a BDD spec written with the in-repo DSL in
  `test/spec.vim`. Run `make test` before reporting any task as done.
- Work is atomic and reviewed. One logical change per commit, and never commit
  without maintainer approval.
- Stage files explicitly. Never `git add -A`.

## Layers and dependencies

Dependencies point inward only:

- `domain/` imports neither `app/` nor `infra/`.
- `app/` imports no `infra/`.
- `plugin/keyhabits.vim` is the composition root: the only place that wires
  concrete infrastructure (`infra/`) into use cases (`app/`).

`autoload/keyhabits/domain/stats.vim` is pure: it takes lists and dicts and
returns plain data, and it never touches files, autocmds or timers.

## Commit messages

An imperative subject under 72 characters with a type prefix (`feat`, `fix`,
`test`, `docs`, `build`, `refactor`, `chore`), a blank line, then a body
explaining what changed and why, wrapped at 72 characters.

```
feat: add Top to rank counts

Top() sorts entries by count descending and breaks ties by key so that
reports are stable across runs. It stays pure by taking a plain dict,
which keeps domain code independent of infrastructure.
```

## Tests

`make test` runs every `test/*_spec.vim` through `test/run.vim` and exits
non-zero on any failure. Specs must not depend on the user's vimrc, installed
plugins or the real log file; file-based specs use `tempname()`.

Always run Vim headless in exactly this form:

```
timeout -s KILL 60 vim -Nu NONE -i NONE -es --not-a-term -S <file> </dev/null
```

Without `</dev/null` an erroring script drops Vim into Ex mode reading stdin
and hangs. The spec DSL prints with `:verbose echo`, which writes to fd 1
without reopening it, so it also works when stdout is a pipe or a socket.

Headless `-es` never leaves Ex mode: `mode(1)` is `ce`, `SafeState` never
fires, and feeding `x` runs `:xit`. Specs that feed keys use `j` and call
grouping hooks directly.

## Vim9script style

- Every file starts with `vim9script`.
- `def` for functions, never `function`. Type every parameter and return
  value.
- Share code with `export` and `import autoload`.
- No legacy Vimscript.
- Two-space indent, no tabs.
- `snake_case` for variables, `PascalCase` for functions and classes.
- One export per concept: a module exports one thing, not a grab bag.
- Target Vim 9.2. Check `:help` in Vim itself when unsure about an API rather
  than guessing; grep the runtime docs for help text.
