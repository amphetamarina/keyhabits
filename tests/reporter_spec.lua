local spec = require("spec")
local reporter = require("keyhabits.app.reporter")
local tips = require("keyhabits.domain.tips")
local describe, it, expect = spec.describe, spec.it, spec.expect

local function ev(overrides)
  return vim.tbl_extend("force", {
    ts = 1700000000,
    sid = "s1",
    grp = 1,
    mode = "n",
    key = "j",
    typed = "j",
    ft = "tex",
  }, overrides)
end

local function keep_all(tip)
  return tip
end

local function build(events, options)
  return reporter.build(events, vim.tbl_extend("force", { limit = 10, tips = tips, resolve = keep_all }, options or {}))
end

local function motions(key, count, overrides)
  local events = {}
  for grp = 1, count do
    events[grp] = ev(vim.tbl_extend("force", { grp = grp, typed = key }, overrides or {}))
  end
  return events
end

describe("reporter.build", function()
  it("reports zeros and empty lists for no events", function()
    local report = build({})
    expect({ report.total_keys, report.sessions, report.time_span }):to_equal({ 0, 0, { 0, 0 } })
    expect({ report.advice, report.untipped, report.top_keys }):to_equal({ {}, {}, {} })
  end)

  it("counts totals, sessions, the time span and the top sections", function()
    local events = {
      ev({ ts = 100, sid = "a", typed = "c" }),
      ev({ ts = 150, sid = "a", typed = "i", mode = "no" }),
      ev({ ts = 200, sid = "a", typed = "w", mode = "no" }),
      ev({ ts = 300, sid = "b", grp = 2, typed = "k" }),
    }
    local report = build(events)
    expect({ report.total_keys, report.sessions, report.time_span }):to_equal({ 4, 2, { 100, 300 } })
    expect(report.top_commands):to_equal({ { "ciw", 1 }, { "k", 1 } })
    expect(report.top_bigrams):to_equal({ { "ci", 1 }, { "iw", 1 } })
  end)

  it("drops events older than since", function()
    local report = build({ ev({ ts = 100 }), ev({ ts = 300, typed = "k" }) }, { since = 250 })
    expect(report.top_keys):to_equal({ { "k", 1 } })
  end)

  it("turns a run of motions into advice with its source", function()
    local advice = build(motions("j", 6)).advice
    expect(#advice):to_be(1)
    expect({ advice[1].id, advice[1].help, advice[1].runs, advice[1].saved }):to_equal({ "repeated-j", "count", 1, 4 })
  end)

  it("does not match a run across sessions", function()
    local events = vim.list_extend(motions("j", 2, { sid = "a" }), motions("j", 2, { sid = "b" }))
    expect(build(events).advice):to_equal({})
  end)

  it("shows a tip as resolve() shapes it and leaves out what it rejects", function()
    local function flash(tip)
      if tip.id == "far-j" then
        return vim.tbl_extend("force", tip, { tip = "Use s", source = "flash.nvim" })
      end
      return nil
    end
    local advice = build(motions("j", 20), { resolve = flash }).advice
    expect({ advice[1].tip, advice[1].source }):to_equal({ "Use s", "flash.nvim" })
    expect(build(motions("j", 6), { resolve = flash }).advice):to_equal({})
  end)

  it("ranks advice by keys saved and truncates it to the limit", function()
    local events =
      vim.list_extend({ ev({ grp = 0, typed = "d" }), ev({ grp = 0, typed = "$", mode = "no" }) }, motions("x", 5))
    local advice = build(events, { limit = 1 }).advice
    expect({ #advice, advice[1].id, advice[1].saved }):to_equal({ 1, "repeated-x", 3 })
  end)

  it("lists a repeated command that has no tip yet", function()
    local events = {}
    for grp = 1, 3 do
      events[#events + 1] = ev({ grp = grp, typed = "g" })
      events[#events + 1] = ev({ grp = grp, typed = "p" })
    end
    expect(build(events).untipped):to_equal({ { "gp", 3 } })
  end)
end)
