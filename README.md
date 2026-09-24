# keyhabits

keyhabits is a Neovim plugin that watches every key you press, remembers the
mode it was pressed in, and turns that stream into a report of your most
repeated keystrokes and commands. Recording is cheap: keys are buffered in
memory and written to a plain append-only JSONL file in batches. Printable text
typed in Insert, Replace, Command-line and Terminal modes is recorded as
`<text>`, so counts and rhythm survive while content does not. Written in Lua,
no required dependencies.

Keys that plugins such as which-key or mini.ai read and feed back to Neovim
are counted once, as you typed them, so the numbers hold in LazyVim.

The Vim 9 version is kept on the `legacy-vim9` branch; both write the same
log format.

## Requirements

- Neovim 0.11 or newer.

## Installation

With LazyVim, add `~/.config/nvim/lua/plugins/keyhabits.lua`:

```lua
return {
  "amphetamarina/keyhabits",
  event = "VeryLazy",
  opts = {},
  keys = {
    { "<leader>uK", "<cmd>KeyHabits report<cr>", desc = "Key Habits Report" },
  },
}
```

Anywhere else, put the plugin on the runtime path and call
`require("keyhabits").setup()`.

## Usage

Recording starts when `setup()` runs. After using Neovim for a while:

    :KeyHabits            " the report
    :KeyHabits report 7   " the last seven days

The report opens in a float; `q` closes it.

| command | effect |
|---------|--------|
| `:KeyHabits [report [days]]` | open the report, optionally for the last `days` days |
| `:KeyHabits start` / `stop` | start or stop recording |
| `:KeyHabits[!] clear` | delete the log after a confirmation; `!` skips it |

`:checkhealth keyhabits` shows whether recording runs and where the log is.

## Options

The defaults:

```lua
opts = {
  log_file = "$XDG_DATA_HOME/keyhabits/events.jsonl", -- else ~/.local/share/...
  auto_start = true, -- record from setup()
  flush_threshold = 200, -- events buffered before they are written
  flush_interval = 30000, -- ms between writes of a partial buffer; 0 disables
  record_text = false, -- record typed text; the log then holds passwords too
  report = { limit = 20 }, -- entries per ranked section
}
```

## The report

- **Top keys**: the keys you physically typed.
- **Top commands**: the commands you repeated. A command starts in Normal
  mode and ends when you return to Normal, so `ciw`, the text you type and the
  closing `<Esc>` are one command, with the text counted as one `<text>`.
- **Top key pairs**: keys that follow each other, within one session.
- **Modes** and **Filetypes**: where your keys went.

## Privacy

In Insert, Replace, Command-line and Terminal modes the printable characters
are the text you are entering, which can include passwords. They are stored as
`<text>`; special keys such as `<Esc>`, `<C-w>` and `<CR>` are stored as they
are. **With `record_text = true` the log contains everything you type,
including passwords, in clear text.**

## Development

`make test` runs every spec in `nvim --headless --clean`; `make lint` runs
stylua and lua-language-server. The layering is in `docs/ARCHITECTURE.md`, the
conventions in `AGENTS.md`.
