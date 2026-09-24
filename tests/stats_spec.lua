local spec = require("spec")
local stats = require("keyhabits.domain.stats")
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

describe("stats with no events", function()
  it("returns empty results from every aggregation", function()
    expect(stats.count_keys({})):to_equal({})
    expect(stats.group_commands({})):to_equal({})
    expect(stats.key_sequences({})):to_equal({})
    expect(stats.sessions({})):to_equal({})
  end)
end)

describe("stats.count_keys, count_modes and count_filetypes", function()
  it("counts typed keys, modes, and an empty filetype as [none]", function()
    local events = { ev({ typed = "j" }), ev({ typed = "j", mode = "i", ft = "" }), ev({ typed = "k" }) }
    expect(stats.count_keys(events)):to_equal({ j = 2, k = 1 })
    expect(stats.count_modes(events)):to_equal({ n = 2, i = 1 })
    expect(stats.count_filetypes(events)):to_equal({ tex = 2, ["[none]"] = 1 })
  end)
end)

describe("stats.group_commands", function()
  it("joins the keys of one group", function()
    local events = { ev({ typed = "c" }), ev({ typed = "i", mode = "no" }), ev({ typed = "w", mode = "no" }) }
    expect(stats.group_commands(events)):to_equal({ "ciw" })
  end)

  it("collapses a run of typed text into one placeholder", function()
    local events = {
      ev({ typed = "i" }),
      ev({ typed = "<text>", mode = "i" }),
      ev({ typed = "<text>", mode = "i" }),
      ev({ typed = "<Esc>", mode = "i" }),
    }
    expect(stats.group_commands(events)):to_equal({ "i<text><Esc>" })
  end)

  it("drops a group that starts in Insert mode and keeps the Visual family", function()
    local events = {
      ev({ grp = 1, typed = "<text>", mode = "i" }),
      ev({ grp = 2, typed = "v", mode = "v" }),
      ev({ grp = 3, typed = "V", mode = "V" }),
      ev({ grp = 4, typed = "x", mode = "\22" }),
    }
    expect(stats.group_commands(events)):to_equal({ "v", "V", "x" })
  end)

  it("starts a new command when the group or the session changes", function()
    local events = { ev({ grp = 1 }), ev({ grp = 2 }), ev({ grp = 2, sid = "s2" }) }
    expect(stats.group_commands(events)):to_equal({ "j", "j", "j" })
  end)
end)

describe("stats.sessions", function()
  it("gathers a session whose events are interleaved with another", function()
    local events = { ev({ sid = "a", typed = "1" }), ev({ sid = "b", typed = "2" }), ev({ sid = "a", typed = "3" }) }
    local sessions = stats.sessions(events)
    expect(#sessions):to_be(2)
    expect(stats.count_keys(sessions[1])):to_equal({ ["1"] = 1, ["3"] = 1 })
  end)
end)

describe("stats.ngrams and key_sequences", function()
  it("counts sliding windows and rejects a window below one", function()
    expect(stats.ngrams({ "a", "b", "a", "b" }, 2)):to_equal({ ab = 2, ba = 1 })
    expect(stats.ngrams({ "a" }, 2)):to_equal({})
    expect(function()
      stats.ngrams({}, 0)
    end):to_throw("at least 1")
  end)

  it("keeps sessions apart and collapses typed text", function()
    local events = {
      ev({ sid = "a", typed = "<text>" }),
      ev({ sid = "a", typed = "<text>" }),
      ev({ sid = "b", typed = "k" }),
    }
    expect(stats.key_sequences(events)):to_equal({ { "<text>" }, { "k" } })
  end)
end)

describe("stats.top", function()
  it("sorts by count descending, then by name, and truncates to the limit", function()
    expect(stats.top({ a = 2, b = 5, c = 2 }, 2)):to_equal({ { "b", 5 }, { "a", 2 } })
    expect(stats.top({ a = 1 }, 0)):to_equal({ { "a", 1 } })
  end)
end)
