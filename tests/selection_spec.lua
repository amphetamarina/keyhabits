local spec = require("spec")
local selection = require("keyhabits.app.selection")
local describe, it, expect = spec.describe, spec.it, spec.expect

-- An environment with the given plugins and mappings, nothing switched off.
local function env(options)
  options = options or {}
  local plugins = options.plugins or {}
  local mappings = options.mappings or {}
  return {
    has = function(plugin)
      return plugins[plugin] == true
    end,
    remapped = function(mode, key)
      return mappings[mode .. ":" .. key]
    end,
    mapped = function(mode, key)
      return (options.present or {})[mode .. ":" .. key]
    end,
    disabled = options.disabled or {},
  }
end

local plain = { id = "repeated-j", tip = "Use 5j", help = "count", suggests = { "j" } }
local with_variant = {
  id = "far-j",
  tip = "Use CTRL-D",
  help = "CTRL-D",
  suggests = { "<C-D>" },
  variants = { { requires = "flash.nvim", tip = "Use s", help = "flash-help", suggests = {} } },
}

describe("selection.resolve", function()
  it("shows a tip unchanged when nothing stands in its way", function()
    expect(selection.resolve(plain, env())):to_equal(plain)
  end)

  it("leaves out a tip switched off in setup", function()
    local shown, reason = selection.resolve(plain, env({ disabled = { ["repeated-j"] = true } }))
    expect(shown):to_be_nil()
    expect(reason):to_be("switched off in setup()")
  end)

  it("leaves out a tip whose plugin is missing", function()
    local needs = vim.tbl_extend("force", plain, { requires = "mini.ai" })
    local shown, reason = selection.resolve(needs, env())
    expect(shown):to_be_nil()
    expect(reason):to_be("needs mini.ai")
    expect(selection.resolve(needs, env({ plugins = { ["mini.ai"] = true } })).id):to_be("repeated-j")
  end)

  it("leaves out a tip whose key is mapped to something else, saying to what", function()
    local shown, reason = selection.resolve(plain, env({ mappings = { ["n:j"] = "Next buffer" } }))
    expect(shown):to_be_nil()
    expect(reason):to_be('j is mapped to "Next buffer" in your config')
  end)

  it("checks an Insert or Visual key in its own mode", function()
    local insert = vim.tbl_extend("force", plain, { suggests = { "i:<C-W>" } })
    expect(selection.resolve(insert, env({ mappings = { ["n:<C-W>"] = "Windows" } })).id):to_be("repeated-j")
    expect(selection.resolve(insert, env({ mappings = { ["i:<C-W>"] = "Other" } }))):to_be_nil()
  end)

  it("uses the variant of a plugin that is there, and marks its source", function()
    local shown = selection.resolve(with_variant, env({ plugins = { ["flash.nvim"] = true } }))
    expect({ shown.tip, shown.help, shown.source }):to_equal({ "Use s", "flash-help", "flash.nvim" })
  end)

  it("does not check the variant's plugin key against the mappings the plugin made", function()
    local mapped = env({ plugins = { ["flash.nvim"] = true }, mappings = { ["n:s"] = "Flash" } })
    expect(selection.resolve(with_variant, mapped).tip):to_be("Use s")
  end)

  it("keeps the plain tip when the variant's plugin is missing", function()
    expect(selection.resolve(with_variant, env()).tip):to_be("Use CTRL-D")
  end)
end)

describe("selection.resolve with mappings", function()
  local window = {
    id = "window-move",
    tip = "Use CTRL-J",
    help = "CTRL-W_j",
    suggests = {},
    needs_mapping = "<C-J>",
    source = "LazyVim",
  }

  it("shows a tip that relies on a mapping only when the mapping is there", function()
    local shown = selection.resolve(window, env({ present = { ["n:<C-J>"] = "Go to Lower Window" } }))
    expect({ shown.tip, shown.source }):to_equal({ "Use CTRL-J", "LazyVim" })
    local missing, reason = selection.resolve(window, env())
    expect(missing):to_be_nil()
    expect(reason):to_be("needs <C-J> mapped, as LazyVim does")
  end)

  it("takes a variant only when its plugin and its mapping are both there", function()
    local search = {
      id = "repeated-next-match",
      tip = "Use 3n",
      help = "n",
      suggests = {},
      variants = {
        {
          requires = "flash.nvim",
          needs_mapping = "c:<C-S>",
          source = "flash",
          tip = "CTRL-S",
          help = "f",
          suggests = {},
        },
      },
    }
    local both = env({ plugins = { ["flash.nvim"] = true }, present = { ["c:<C-S>"] = "Toggle Flash Search" } })
    expect(selection.resolve(search, both).tip):to_be("CTRL-S")
    expect(selection.resolve(search, env({ plugins = { ["flash.nvim"] = true } })).tip):to_be("Use 3n")
    expect(selection.resolve(search, env({ present = { ["c:<C-S>"] = "x" } })).tip):to_be("Use 3n")
  end)
end)

describe("selection.split", function()
  it("splits a catalogue into shown tips and left-out ones with reasons", function()
    local active, skipped = selection.split({ plain, with_variant }, env({ mappings = { ["n:<C-D>"] = "Down" } }))
    expect(#active):to_be(1)
    expect(skipped[1].tip.id):to_be("far-j")
    expect(skipped[1].reason):to_contain("<C-D> is mapped")
  end)
end)
