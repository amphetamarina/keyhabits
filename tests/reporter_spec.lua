local spec = require("spec")
local reporter = require("keyhabits.app.reporter")
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

local function build(events, options)
  return reporter.build(events, vim.tbl_extend("force", { limit = 10 }, options or {}))
end

describe("reporter.build", function()
  it("reports zeros and empty lists for no events", function()
    local report = build({})
    expect({ report.total_keys, report.sessions, report.time_span }):to_equal({ 0, 0, { 0, 0 } })
    expect({ report.top_keys, report.top_commands, report.modes }):to_equal({ {}, {}, {} })
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
    expect(report.modes):to_equal({ { "n", 2 }, { "no", 2 } })
    expect(report.filetypes):to_equal({ { "tex", 4 } })
  end)

  it("drops events older than since", function()
    local report = build({ ev({ ts = 100 }), ev({ ts = 300, typed = "k" }) }, { since = 250 })
    expect(report.top_keys):to_equal({ { "k", 1 } })
  end)

  it("truncates the ranked sections to the limit but keeps all modes", function()
    local events = {
      ev({ grp = 1, typed = "a" }),
      ev({ grp = 2, typed = "b" }),
      ev({ grp = 3, typed = "c", mode = "v" }),
    }
    local report = build(events, { limit = 1 })
    expect(report.top_keys):to_equal({ { "a", 1 } })
    expect(report.modes):to_equal({ { "n", 2 }, { "v", 1 } })
  end)

  it("counts key pairs within a session only", function()
    local events = {
      ev({ sid = "a", typed = "a" }),
      ev({ sid = "a", typed = "b" }),
      ev({ sid = "b", typed = "b" }),
      ev({ sid = "b", typed = "c" }),
    }
    expect(build(events).top_bigrams):to_equal({ { "ab", 1 }, { "bc", 1 } })
  end)
end)
