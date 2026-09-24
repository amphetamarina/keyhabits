local spec = require("spec")
local advice = require("keyhabits.domain.advice")
local tips = require("keyhabits.domain.tips")
local describe, it, expect = spec.describe, spec.it, spec.expect

local function only(id)
  return vim.tbl_filter(function(tip)
    return tip.id == id
  end, tips)
end

local function rep(command, times)
  local commands = {}
  for index = 1, times do
    commands[index] = command
  end
  return commands
end

describe("the tip catalogue", function()
  it("cites a help tag Neovim has for every tip that needs no plugin", function()
    local missing = {}
    for _, tip in ipairs(tips) do
      if not tip.requires and not vim.tbl_contains(vim.fn.getcompletion(tip.help, "help"), tip.help) then
        missing[#missing + 1] = tip.id .. ": " .. tip.help
      end
    end
    expect(missing):to_equal({})
  end)

  it("gives every tip a unique id", function()
    local seen, duplicates = {}, {}
    for _, tip in ipairs(tips) do
      if seen[tip.id] then
        duplicates[#duplicates + 1] = tip.id
      end
      seen[tip.id] = true
    end
    expect(duplicates):to_equal({})
  end)

  it("states the keys saved in exactly one way", function()
    local unclear = {}
    for _, tip in ipairs(tips) do
      if (tip.fix ~= nil) == (tip.saves ~= nil) then
        unclear[#unclear + 1] = tip.id
      end
    end
    expect(unclear):to_equal({})
  end)

  it("gives every tip and variant a tip, a help tag and its suggested keys", function()
    local incomplete = {}
    for _, tip in ipairs(tips) do
      local entries = vim.list_extend({ tip }, tip.variants or {})
      for _, entry in ipairs(entries) do
        if type(entry.tip) ~= "string" or type(entry.help) ~= "string" or type(entry.suggests) ~= "table" then
          incomplete[#incomplete + 1] = tip.id
        end
      end
      if #tip.sequence == 0 or tip.min < 1 or (tip.repeats and #tip.repeats ~= #tip.sequence) then
        incomplete[#incomplete + 1] = tip.id
      end
    end
    expect(incomplete):to_equal({})
  end)

  it("matches each tip's example with that tip first, saving keys", function()
    local broken = {}
    for _, tip in ipairs(tips) do
      local found = advice.match(tip.example, tips)
      local ids = vim.tbl_keys(found)
      if #ids ~= 1 or ids[1] ~= tip.id or found[tip.id].runs ~= 1 or found[tip.id].saved < 1 then
        broken[#broken + 1] = tip.id .. ": " .. vim.inspect(found)
      end
    end
    expect(broken):to_equal({})
  end)

  it("holds more than a hundred tips", function()
    expect(#tips > 100):to_be_true()
  end)
end)

describe("advice.key_count", function()
  it("counts plain keys, a named key as one, and leaves typed text out", function()
    expect(advice.key_count("3dd")):to_be(3)
    expect(advice.key_count("<C-D>")):to_be(1)
    expect(advice.key_count("f<lt>")):to_be(2)
    expect(advice.key_count("ciw<text><Esc>")):to_be(4)
  end)
end)

describe("advice.match", function()
  it("finds nothing in no commands", function()
    expect(advice.match({}, tips)):to_equal({})
  end)

  it("counts a run of j as one run and the keys a count saves", function()
    expect(advice.match(rep("j", 6), tips)):to_equal({ ["repeated-j"] = { runs = 1, saved = 4 } })
  end)

  it("ignores a run shorter than the minimum", function()
    expect(advice.match(rep("j", 3), tips)):to_equal({})
  end)

  it("prefers a long run over the shorter habit it starts with", function()
    expect(vim.tbl_keys(advice.match(rep("j", 20), tips))):to_equal({ "far-j" })
  end)

  it("counts separate runs separately", function()
    local commands = { "x", "x", "x", "w", "x", "x", "x", "x" }
    expect(advice.match(commands, tips)):to_equal({ ["repeated-x"] = { runs = 2, saved = 3 } })
  end)

  it("matches whole commands only", function()
    expect(advice.match({ "5j", "jj", "d$x" }, tips)):to_equal({})
  end)

  it("does not match a sequence that is interrupted", function()
    expect(advice.match({ "$", "j", "a<text><Esc>" }, tips)):to_equal({})
  end)

  it("uses the fixed saving for a tip whose commands carry an Insert", function()
    expect(advice.match({ "$", "a<text><BS><text><CR><text><Esc>" }, tips)):to_equal({
      ["end-then-append"] = { runs = 1, saved = 1 },
    })
  end)

  it("asks for the same command when a tip says same", function()
    expect(advice.match({ "f(", "f(" }, only("repeated-find"))):to_equal({
      ["repeated-find"] = { runs = 1, saved = 1 },
    })
    expect(advice.match({ "f(", "f)" }, only("repeated-find"))):to_equal({})
  end)

  it("charges the better way for each repeat with fix_each", function()
    expect(advice.match(rep("ta", 4), only("repeated-find"))):to_equal({
      ["repeated-find"] = { runs = 1, saved = 3 },
    })
  end)

  it("counts every matching part inside one command", function()
    local command = "a<text><BS><BS><BS><BS><BS><text><BS><BS><BS><BS><BS><BS><Esc>"
    expect(advice.match({ command }, only("backspace-run"))):to_equal({
      ["backspace-run"] = { runs = 2, saved = 9 },
    })
  end)

  it("takes each step of a tip with repeats as a run of at least its minimum", function()
    expect(advice.match({ "j", "j", "j", "j", "j", "k", "k" }, tips)):to_equal({
      ["overshoot-down"] = { runs = 1, saved = 5 },
    })
    expect(advice.match({ "j", "k" }, only("overshoot-down"))):to_equal({})
  end)

  it("uses only the tips it is given", function()
    expect(advice.match({ "d$", "j", "j", "j", "j" }, only("delete-to-end"))):to_equal({
      ["delete-to-end"] = { runs = 1, saved = 1 },
    })
  end)
end)

describe("advice.uncovered", function()
  it("lists a command repeated three or more times that no tip covers", function()
    expect(advice.uncovered({ ":<text><CR>", ":<text><CR>", ":<text><CR>", "j" }, tips)):to_equal({
      [":<text><CR>"] = { runs = 1, presses = 3 },
    })
  end)

  it("leaves out covered commands and runs of two", function()
    expect(advice.uncovered({ "j", "j", "j", "gp", "gp" }, tips)):to_equal({})
  end)

  it("adds up separate runs of the same command", function()
    expect(advice.uncovered({ "gp", "gp", "gp", "w", "gp", "gp", "gp", "gp" }, tips)):to_equal({
      gp = { runs = 2, presses = 7 },
    })
  end)
end)
