local spec = require("spec")
local event = require("keyhabits.domain.event")
local describe, it, expect = spec.describe, spec.it, spec.expect

local function raw(overrides)
  return vim.tbl_extend("force", {
    ts = 1700000000,
    sid = "1234-1700000000",
    grp = 7,
    mode = "n",
    key = "j",
    typed = "j",
    ft = "tex",
  }, overrides)
end

describe("event.new", function()
  it("builds exactly the seven documented fields", function()
    local built = event.new(raw({}))
    local names = vim.tbl_keys(built)
    table.sort(names)
    expect(names):to_equal({ "ft", "grp", "key", "mode", "sid", "ts", "typed" })
    expect(built.typed):to_be("j")
  end)

  it("names special keys with keytrans", function()
    expect(event.new(raw({ typed = vim.keycode("<Esc>") })).typed):to_be("<Esc>")
    expect(event.new(raw({ typed = vim.keycode("<C-W>") })).typed):to_be("<C-W>")
    expect(event.new(raw({ typed = " " })).typed):to_be("<Space>")
    expect(event.new(raw({ typed = "<" })).typed):to_be("<lt>")
  end)

  it("keeps a mapping's left-hand side as one name", function()
    expect(event.new(raw({ key = vim.keycode("<Cmd>"), typed = " ff" })).typed):to_be("<Space>ff")
  end)

  it("redacts text typed in Insert, Replace, Command-line and Terminal modes", function()
    for _, mode in ipairs({ "i", "ic", "R", "c", "t" }) do
      for _, typed in ipairs({ "a", " ", "<", "é" }) do
        local built = event.new(raw({ mode = mode, key = typed, typed = typed }))
        expect(built.typed):to_be("<text>")
        expect(built.key):to_be("<text>")
      end
    end
  end)

  it("redacts a mapping's printable left-hand side in a text mode", function()
    expect(event.new(raw({ mode = "i", typed = "jk" })).typed):to_be("<text>")
  end)

  it("keeps special keys in a text mode", function()
    for _, name in ipairs({ "<Esc>", "<C-W>", "<BS>", "<Tab>", "<CR>", "<Left>" }) do
      expect(event.new(raw({ mode = "i", key = vim.keycode(name), typed = vim.keycode(name) })).typed):to_be(name)
    end
  end)

  it("never redacts Normal mode keys", function()
    expect(event.new(raw({ mode = "n", typed = "a" })).typed):to_be("a")
  end)

  it("records text as typed when record_text is true", function()
    expect(event.new(raw({ mode = "i", typed = "a" }), true).typed):to_be("a")
  end)
end)

describe("event.encode and event.decode", function()
  it("round trips an event", function()
    local built = event.new(raw({}))
    expect(event.decode(event.encode(built))):to_equal(built)
  end)

  it("rejects invalid JSON", function()
    expect(function()
      event.decode("{nope")
    end):to_throw("not valid JSON")
  end)

  it("rejects a value that is not an object", function()
    expect(function()
      event.decode("[1, 2]")
    end):to_throw("expected a JSON object")
  end)

  -- JSON key order is not fixed, so the bad lines are built from tables.
  it("rejects a missing field, a wrong type and an unknown field", function()
    local function line_with(change)
      local ev = event.new(raw({}))
      change(ev)
      return event.encode(ev)
    end
    expect(function()
      event.decode(line_with(function(ev)
        ev.ft = nil
      end))
    end):to_throw("missing field ft")
    expect(function()
      event.decode(line_with(function(ev)
        ev.grp = "7"
      end))
    end):to_throw("field grp must be a number")
    expect(function()
      event.decode(line_with(function(ev)
        ev.extra = 1
      end))
    end):to_throw("unknown field extra")
  end)
end)
