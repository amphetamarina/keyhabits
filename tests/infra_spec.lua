local spec = require("spec")
local JsonlStore = require("keyhabits.infra.jsonl_store")
local MemoryStore = require("keyhabits.infra.memory_store")
local Recorder = require("keyhabits.app.recorder")
local capture = require("keyhabits.infra.capture")
local config = require("keyhabits.config")
local report_view = require("keyhabits.infra.report_view")
local describe, it, expect = spec.describe, spec.it, spec.expect

describe("config.merge", function()
  it("returns the documented defaults", function()
    local merged = config.merge()
    expect(merged.auto_start):to_be_true()
    expect(merged.flush_threshold):to_be(200)
    expect(merged.report):to_equal({ limit = 20 })
    expect(merged.log_file):to_contain("/keyhabits/events.jsonl")
  end)

  it("merges nested options and expands the log path", function()
    local merged = config.merge({ log_file = "~/k.jsonl", report = { limit = 5 } })
    expect(merged.log_file):to_be(vim.fn.expand("~/k.jsonl"))
    expect({ merged.report.limit, merged.flush_threshold }):to_equal({ 5, 200 })
  end)

  it("rejects a bad value", function()
    expect(function()
      config.merge({ report = { limit = 0 } })
    end):to_throw("report.limit must be a number of at least 1")
    expect(function()
      config.merge({ record_text = "yes" })
    end):to_throw("record_text")
  end)
end)

describe("JsonlStore", function()
  it("appends events, reads them back and clears the file", function()
    local path = vim.fn.tempname() .. "/dir/events.jsonl"
    local store = JsonlStore.new(path)
    local ev = { ts = 1, sid = "s", grp = 0, mode = "n", key = "j", typed = "j", ft = "" }
    store:append({ ev })
    store:append({ ev })
    expect(store:read_all()):to_equal({ ev, ev })
    store:clear()
    expect(store:read_all()):to_equal({})
  end)

  it("skips and counts a corrupt line", function()
    local path = vim.fn.tempname()
    vim.fn.writefile({ "{broken", '{"ts":1,"sid":"s","grp":0,"mode":"n","key":"j","typed":"j","ft":""}' }, path)
    local store = JsonlStore.new(path)
    expect(#store:read_all()):to_be(1)
    expect(store.skipped):to_be(1)
  end)
end)

describe("capture", function()
  it("ends a command only in Normal proper, and treats SafeState as a boundary in Normal", function()
    expect({ capture.is_command_end("n"), capture.is_command_end("no"), capture.is_command_end("i") }):to_equal({
      true,
      false,
      false,
    })
    expect({ capture.is_safe_boundary("n"), capture.is_safe_boundary("i"), capture.is_safe_boundary("v") }):to_equal({
      true,
      false,
      false,
    })
  end)

  -- Feeds { name, ms, grp } reports through new_part and returns what each
  -- adds.
  local function parts(reports)
    local keys, added = capture.new_keys(), {}
    for _, report in ipairs(reports) do
      added[#added + 1] = capture.new_part(keys, report[1], report[3] or 1, report[2] * 1e6)
    end
    return added
  end

  it("keeps real key presses, repeats included", function()
    expect(parts({ { "d", 0 }, { "d", 120 } })):to_equal({ "d", "d" })
    expect(parts({ { "d", 0 }, { "w", 100 }, { "w", 130 } })):to_equal({ "d", "w", "w" })
  end)

  it("drops which-key feeding back the last key or the whole command", function()
    expect(parts({ { "d", 0 }, { "w", 100 }, { "w", 100.3 } })):to_equal({ "d", "w", "" })
    expect(parts({ { "<Space>", 0 }, { "u", 120 }, { "l", 240 }, { "<Space>ul", 241.6 } })):to_equal({
      "<Space>",
      "u",
      "l",
      "",
    })
  end)

  it("drops which-key feeding the command back key by key", function()
    expect(parts({ { "<C-W>", 0 }, { "j", 120 }, { "<C-W>", 122 }, { "j", 122 } })):to_equal({ "<C-W>", "j", "", "" })
  end)

  it("keeps the new key when mini.ai reports it with the one before", function()
    expect(parts({ { "v", 0 }, { "i", 120 }, { "iw", 400 } })):to_equal({ "v", "i", "w" })
  end)

  it("does not count the keys of an earlier command", function()
    expect(parts({ { "d", 0, 1 }, { "w", 100, 1 }, { "w", 100.3, 2 } })):to_equal({ "d", "w", "w" })
  end)

  it("records typed keys and drops keys nothing typed", function()
    local store = MemoryStore.new()
    local subject = capture.new({ recorder = Recorder.new(store, 1), record_text = false, flush_interval = 0 })
    subject:on_key("g", "j")
    subject:on_key("j", "")
    local events = store:read_all()
    expect(#events):to_be(1)
    expect({ events[1].key, events[1].typed, events[1].mode }):to_equal({ "g", "j", "n" })
  end)

  it("starts and stops cleanly, twice in a row", function()
    local store = MemoryStore.new()
    local subject = capture.new({ recorder = Recorder.new(store, 1000), record_text = false, flush_interval = 10 })
    subject:start()
    subject:start()
    expect(subject:is_running()):to_be_true()
    subject:on_key("j", "j")
    subject:stop()
    subject:stop()
    expect(subject:is_running()):to_be_false()
    expect(#store:read_all()):to_be(1)
  end)
end)

describe("report_view", function()
  local report = {
    total_keys = 3,
    sessions = 1,
    time_span = { 1700000000, 1700000100 },
    top_keys = { { "j", 2 } },
    top_commands = { { "j", 2 } },
    top_bigrams = { { "jj", 1 } },
    modes = { { "n", 2 }, { "no", 1 }, { "ic", 1 } },
    filetypes = { { "tex", 3 } },
  }

  it("renders the span, the counters and every section", function()
    local lines = report_view.render(report)
    expect(vim.list_slice(lines, 3, 6)):to_equal({ "keys: 3  sessions: 1", "", "Top keys", "     2  j" })
    expect(lines):to_contain("Top commands")
    expect(lines):to_contain("Top key pairs")
    expect(lines):to_contain("     3  Normal")
    expect(lines):to_contain("     1  Insert")
    expect(lines[#lines]):to_be("     3  tex")
  end)

  it("renders an empty report as a notice", function()
    expect(report_view.render({ total_keys = 0 })):to_equal({ "keyhabits report", "no events recorded" })
  end)

  it("opens a float that q closes", function()
    local lines = report_view.render(report)
    local buf, win = report_view.open(lines)
    expect(vim.api.nvim_win_get_config(win).relative):to_be("editor")
    expect(vim.api.nvim_buf_get_lines(buf, 0, -1, false)):to_equal(lines)
    vim.api.nvim_feedkeys("q", "x", false)
    expect(vim.api.nvim_win_is_valid(win)):to_be_false()
  end)
end)
