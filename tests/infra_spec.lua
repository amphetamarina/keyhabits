local spec = require("spec")
local JsonlStore = require("keyhabits.infra.jsonl_store")
local MemoryStore = require("keyhabits.infra.memory_store")
local Notifier = require("keyhabits.infra.notifier")
local Recorder = require("keyhabits.app.recorder")
local capture = require("keyhabits.infra.capture")
local config = require("keyhabits.config")
local environment = require("keyhabits.infra.environment")
local report_view = require("keyhabits.infra.report_view")
local describe, it, expect = spec.describe, spec.it, spec.expect

describe("config.merge", function()
  it("returns the documented defaults", function()
    local merged = config.merge()
    expect(merged.auto_start):to_be_true()
    expect(merged.flush_threshold):to_be(200)
    expect(merged.tips):to_equal({ enabled = true, threshold = 1, window = 60, cooldown = 600, disable = {} })
    expect(merged.log_file):to_contain("/keyhabits/events.jsonl")
  end)

  it("merges nested options and expands the log path", function()
    local merged = config.merge({ log_file = "~/k.jsonl", tips = { cooldown = 5 } })
    expect(merged.log_file):to_be(vim.fn.expand("~/k.jsonl"))
    expect({ merged.tips.cooldown, merged.tips.window }):to_equal({ 5, 60 })
  end)

  it("rejects a bad value", function()
    expect(function()
      config.merge({ tips = { threshold = 0 } })
    end):to_throw("tips.threshold must be a number of at least 1")
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

  local function listening(heard, store)
    return capture.new({
      recorder = Recorder.new(store or MemoryStore.new(), 1000),
      record_text = false,
      flush_interval = 0,
      on_command = function(command)
        heard[#heard + 1] = command
      end,
    })
  end

  it("keeps only what a report adds to the keys just recorded for the command", function()
    local ms = 1e6
    local dw = { { name = "d", at = 0, grp = 1 }, { name = "w", at = 100 * ms, grp = 1 } }
    -- which-key feeding the last key, or the command, back
    expect(capture.new_part(dw, "w", 1, 100.3 * ms)):to_be("")
    expect(capture.new_part(dw, "dw", 1, 101 * ms)):to_be("")
    -- a real second press, too slow to be a replay
    expect(capture.new_part(dw, "w", 1, 130 * ms)):to_be("w")
    expect(capture.new_part(dw, "x", 1, 100.3 * ms)):to_be("x")
    expect(capture.new_part({}, "w", 1, 0)):to_be("w")
    -- the keys of an earlier command do not count
    expect(capture.new_part(dw, "w", 2, 100.3 * ms)):to_be("w")
    local leader = {
      { name = "<Space>", at = 0, grp = 3 },
      { name = "u", at = 120 * ms, grp = 3 },
      { name = "l", at = 240 * ms, grp = 3 },
    }
    expect(capture.new_part(leader, "<Space>ul", 3, 241.6 * ms)):to_be("")
    -- mini.ai reading the key after "i" reports "iw"
    local visual = { { name = "v", at = 0, grp = 4 }, { name = "i", at = 120 * ms, grp = 4 } }
    expect(capture.new_part(visual, "iw", 4, 400 * ms)):to_be("w")
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

  it("hands each finished command to the listener", function()
    local heard = {}
    local subject = listening(heard)
    for _, key in ipairs({ "c", "i", "w" }) do
      subject:on_key(key, key)
    end
    subject:next_group()
    subject:on_key("j", "j")
    subject:next_group()
    subject:next_group()
    expect(heard):to_equal({ "ciw", "j" })
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

describe("environment", function()
  it("sees a key mapped to something else, and not one that keeps its meaning", function()
    vim.keymap.set("n", "H", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
    vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = "Down" })
    vim.keymap.set("n", "s", function() end, { desc = "Flash" })
    vim.keymap.set("n", "f", function() end)
    vim.keymap.set("n", "<C-F>", function()
      return "<C-F>"
    end, { expr = true, desc = "Scroll Forward" })
    vim.keymap.set("n", "g", function() end, { desc = "which-key-trigger" })
    expect(environment.remapped("n", "<C-F>")):to_be_nil()
    expect(environment.remapped("n", "g")):to_be_nil()
    expect(environment.remapped("n", "H")):to_be("Prev Buffer")
    expect(environment.remapped("n", "s")):to_be("Flash")
    expect(environment.remapped("n", "j")):to_be_nil()
    expect(environment.remapped("n", "f")):to_be_nil()
    expect(environment.remapped("n", "X")):to_be_nil()
    for _, key in ipairs({ "H", "j", "s", "f", "<C-F>", "g" }) do
      vim.keymap.del("n", key)
    end
  end)

  it("tells a mapped key from an unmapped one", function()
    vim.keymap.set("n", "<C-J>", "<C-w>j", { desc = "Go to Lower Window" })
    vim.keymap.set("n", "<C-K>", "<C-w>k")
    expect(environment.mapped("n", "<C-J>")):to_be("Go to Lower Window")
    expect(environment.mapped("n", "<C-K>")):to_be("")
    expect(environment.mapped("n", "<C-Y>")):to_be_nil()
    vim.keymap.del("n", "<C-J>")
    vim.keymap.del("n", "<C-K>")
  end)

  it("builds the set of switched-off tips", function()
    expect(environment.current({ "a", "b" }).disabled):to_equal({ a = true, b = true })
  end)
end)

describe("Notifier", function()
  it("puts the source and the help under the tip", function()
    expect(Notifier.message({ tip = "Use 5j", help = "count" }, 40)):to_be("Use 5j\n:help count")
    expect(Notifier.message({ tip = "Use s", help = "x", source = "flash.nvim" }, 40)):to_be(
      "Use s\nflash.nvim · :help x"
    )
  end)

  it("wraps a long tip at word boundaries so no line is cut", function()
    local tip = { tip = "Jump straight to the line with s, a few letters and the label flash shows", help = "h" }
    local lines = vim.split(Notifier.message(tip, 30), "\n")
    expect(lines):to_equal({
      "Jump straight to the line with",
      "s, a few letters and the label",
      "flash shows",
      ":help h",
    })
  end)

  it("fits 40% of the screen, between 30 and 60 columns", function()
    local columns = vim.o.columns
    vim.o.columns = 160
    expect(Notifier.width()):to_be(60)
    vim.o.columns = 100
    expect(Notifier.width()):to_be(36)
    vim.o.columns = 40
    expect(Notifier.width()):to_be(30)
    vim.o.columns = columns
  end)

  it("remembers the last tip and shows it with vim.notify", function()
    local original = vim.notify
    local seen = {}
    vim.notify = function(message, _, opts)
      seen[#seen + 1] = { message, opts.title }
    end
    local notifier = Notifier.new()
    notifier:notify({ tip = "Use 5j", help = "count" })
    vim.wait(2000, function()
      return #seen > 0
    end)
    vim.notify = original
    expect(notifier.last.help):to_be("count")
    expect(seen):to_equal({ { Notifier.message({ tip = "Use 5j", help = "count" }), "keyhabits" } })
  end)
end)

describe("report_view", function()
  local report = {
    total_keys = 3,
    sessions = 1,
    time_span = { 1700000000, 1700000100 },
    advice = { { tip = "Use 5j", help = "count", saved = 6, runs = 2 } },
    untipped = { { "gp", 4 } },
    top_keys = { { "j", 2 } },
    top_commands = { { "j", 2 } },
    top_bigrams = { { "jj", 1 } },
    modes = { { "n", 2 }, { "no", 1 }, { "ic", 1 } },
    filetypes = { { "tex", 3 } },
  }

  it("renders advice first, with the help each tip cites by line", function()
    local lines, help_at = report_view.render(report)
    expect(vim.list_slice(lines, 4, 9)):to_equal({
      "",
      report_view.advice_title,
      "     6  Use 5j  (:help count)",
      "",
      report_view.untipped_title,
      "     4  gp",
    })
    expect(help_at):to_equal({ [6] = "count" })
    expect(lines):to_contain("     3  Normal")
    expect(lines):to_contain("     1  Insert")
  end)

  it("renders an empty report as a notice", function()
    expect(report_view.render({ total_keys = 0 })):to_equal({ "keyhabits report", "no events recorded" })
  end)

  it("opens a float that q closes and <CR> turns into the tip's help", function()
    local lines, help_at = report_view.render(report)
    local buf, win = report_view.open(lines, help_at)
    expect(vim.api.nvim_win_get_config(win).relative):to_be("editor")
    expect(vim.api.nvim_buf_get_lines(buf, 0, -1, false)):to_equal(lines)
    vim.api.nvim_win_set_cursor(win, { 6, 0 })
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    expect(vim.bo.buftype):to_be("help")
    vim.cmd.close()
  end)
end)
