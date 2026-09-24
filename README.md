# keyhabits

keyhabits is a Neovim plugin that watches every key you press, remembers the
mode it was pressed in, and turns that stream into a report of your most
repeated keystrokes and commands. When a habit has a better command, such as
`jjjj` where `4j` would do, it tells you right away, and the tip names the
`:help` topic it comes from.

It is built for LazyVim and knows its setup: a tip whose key your config maps
to something else is not shown, and when LazyVim, flash.nvim, mini.ai or a
Neovim default offer a better way, the tip suggests that and says where it
comes from. Printable text typed in Insert, Replace, Command-line and
Terminal modes is recorded as `<text>`, so counts and rhythm survive while
content does not. Written in Lua, no required dependencies.

The Vim 9 version is kept on the `legacy-vim9` branch.

## Requirements

- Neovim 0.11 or newer.

## Installation

With LazyVim, add `~/.config/nvim/lua/plugins/keyhabits.lua`:

```lua
return {
  "amphetamarina/keyhabits",
  event = "VeryLazy",
  opts = {},
  config = function(_, opts)
    require("keyhabits").setup(opts)
    Snacks.toggle({
      name = "Key Habit Tips",
      get = function()
        return require("keyhabits").tips_enabled()
      end,
      set = function(on)
        require("keyhabits").set_tips(on)
      end,
    }):map("<leader>uk")
  end,
  keys = {
    { "<leader>uK", "<cmd>KeyHabits report<cr>", desc = "Key Habits Report" },
  },
}
```

With plain lazy.nvim, drop the `Snacks.toggle` part. Anywhere else, put the
plugin on the runtime path and call `require("keyhabits").setup()`.

## Usage

Recording starts when `setup()` runs. Tips appear as notifications while you
work; after using Neovim for a while:

    :KeyHabits            " the report
    :KeyHabits report 7   " the last seven days

In the report, `<CR>` on a tip opens the help it comes from, and `q` closes it.

| command | effect |
|---------|--------|
| `:KeyHabits [report [days]]` | open the report, optionally for the last `days` days |
| `:KeyHabits start` / `stop` | start or stop recording |
| `:KeyHabits toggle` | turn live tips on or off |
| `:KeyHabits why` | open the help for the last tip shown |
| `:KeyHabits tips` | list the tips active here, and the ones left out with the reason |
| `:KeyHabits[!] clear` | delete the log after a confirmation; `!` skips it |

`:checkhealth keyhabits` shows whether recording runs, where the log is, and
which tips are left out and why.

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
  tips = {
    enabled = true, -- show tips while you work
    threshold = 1, -- times a habit must occur within the window
    window = 60, -- seconds of recent commands watched
    cooldown = 600, -- seconds before the same tip may show again
    disable = {}, -- tip ids never to show, see :KeyHabits tips
  },
}
```

## The tips

123 tips, each backed by the help that ships with Neovim or with the plugin it
needs, and each doing the same thing as the habit it replaces. They cover:

- LazyVim and Neovim: `CTRL-W j` → `CTRL-J`, `ddp` / `ddkP` → `Alt-j` /
  `Alt-k`, `o<Esc>k` → `]<Space>`, eight or more `w` or `b` → flash's `s`
  jump, and repeated `n` → `CTRL-S` during a `/` search for flash's labels;
  each shows only when the mapping or plugin is there

- going past a line and back (`jjjjk`): read the count off the relative
  numbers (`3j`); long runs of `j`/`k`: `CTRL-D`/`CTRL-U`, or flash's `s`
- counts for repeated motions: `j`, `k`, `w`, `b`, `e`, `W`, `B`, `E`, `ge`,
  `}`, `)`, `+`, `-`, `gj`, `n`, `*`, `;`, `,`, `]]`, `]s`, `]c` and their
  twins; `f{char}` for long runs of `l`/`h`; `;` (or flash's `f`) to repeat
  an `f` or `t`
- counts for jumps, views and edits: `CTRL-F`, `CTRL-O`, `g;`, `gT`, `zh`,
  `CTRL-E`, window sizes, `x`, `X`, `dd`, `dw`, `J`, `p`, `u`, `CTRL-R`, `~`,
  `CTRL-A`, `@a`, `@@`; `dd..` → `3dd`; `>>>>>>` → `V3>`
- shorter spellings: `$a` → `A`, `^i` → `I`, `d$a` → `C`, `diwi` → `ciw`,
  `dw dw i` → `c2w`, `dt)i` → `ct)`, `diwx` → `daw`, `ddO` → `cc`,
  `hx` → `X`, `ha` → `i`, `j^` → `+`, `A<CR>` → `o`, `d$` → `D`
- Visual detours: `viwd` → `diw`, `ved` → `de`, `Vjjd` → `3dd`,
  `Vjj>` → `3>>`, `VG=` → `=G`
- Insert editing: `CTRL-W` instead of a run of `<BS>`, `<C-Left>` instead of
  a run of arrows
- with mini.ai: `f(ci(` → `ci(`, since mini.ai finds the next pair itself

Commands you repeat three or more times that no tip covers are listed in the
report under "Repeated, no tip yet", so a missing tip is visible.

## Privacy

In Insert, Replace, Command-line and Terminal modes the printable characters
are the text you are entering, which can include passwords. They are stored as
`<text>`; special keys such as `<Esc>`, `<C-w>` and `<CR>` are stored as they
are. **With `record_text = true` the log contains everything you type,
including passwords, in clear text.**

## Development

`make test` runs every spec in `nvim --headless --clean`. `stylua` formats the
code and `lua-language-server --check lua` must stay quiet. The layering is in
`docs/ARCHITECTURE.md`, the conventions in `AGENTS.md`.
