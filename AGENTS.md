# Working on keyhabits

keyhabits is a Neovim plugin, written in Lua, that records every key press
together with its mode and reports the most repeated keystrokes and commands.
It is built for LazyVim and works in any Neovim 0.11 or newer. It has no
required dependencies.

The Vim 9 version lives on the `legacy-vim9` branch and is not maintained.

`docs/ARCHITECTURE.md` is the source of truth for design and layering;
`docs/BACKLOG.md` is the source of truth for what to build next. Read both
before writing code. If something in them looks wrong, raise it with the
maintainer instead of silently deviating.

## Conventions

- Clean Code and Clean Architecture. Small functions, one responsibility,
  names that say what they do. No dead code, no commented-out code.
- Everything testable has a BDD spec written with the in-repo DSL in
  `tests/spec.lua`. Run `make test` before reporting any task as done.
- Work is atomic and reviewed. One logical change per commit, and never commit
  without maintainer approval.
- Stage files explicitly. Never `git add -A`.

## Layers and dependencies

Dependencies point inward only:

- `lua/keyhabits/domain/` requires neither `app/` nor `infra/`.
- `lua/keyhabits/app/` requires no `infra/`.
- `lua/keyhabits/init.lua` is the composition root: the only place that wires
  concrete infrastructure (`infra/`) into use cases (`app/`).

Domain modules are pure: they take tables and return tables, and never touch
buffers, windows, autocommands, timers, files or options.

## Commit messages

An imperative subject under 72 characters with a type prefix (`feat`, `fix`,
`test`, `docs`, `build`, `refactor`, `chore`), a blank line, then a body
explaining what changed and why, wrapped at 72 characters.

## Tests

`make test` runs every `tests/*_spec.lua` in `nvim --headless --clean` and
exits non-zero on any failure. Specs must not depend on the user's config,
installed plugins or the real log file; file-based specs use `tempname()`.

Headless Neovim never fires `SafeState` and has no LazyVim mappings, so the
live path (keys, command boundaries, which-key and mini.ai behaviour) is
checked by running the real config in a pseudo-terminal, with keys fed one at
a time from a timer.

## Lua style

- `stylua` formats everything (`stylua.toml`: two spaces, 120 columns).
- `make lint` runs stylua and `lua-language-server --check` with no warnings.
- A module returns one table. Classes are tables with `__index` and a `new`
  constructor; methods use `:`.
- `snake_case` for functions and variables, `PascalCase` for classes.
- Target Neovim 0.11+. Check `:help` in Neovim itself when unsure about an API
  rather than guessing.
