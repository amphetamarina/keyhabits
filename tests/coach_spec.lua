local spec = require("spec")
local Coach = require("keyhabits.app.coach")
local tips = require("keyhabits.domain.tips")
local describe, it, expect = spec.describe, spec.it, spec.expect

local function fake_notifier()
  return {
    shown = {},
    notify = function(self, tip)
      self.shown[#self.shown + 1] = tip.id
    end,
  }
end

local function keep_all(tip)
  return tip
end

-- threshold 1, window 60 seconds, cooldown 600 seconds
local function new_coach(notifier, options)
  return Coach.new(vim.tbl_extend("force", {
    notifier = notifier,
    tips = tips,
    resolve = keep_all,
    threshold = 1,
    window = 60,
    cooldown = 600,
  }, options or {}))
end

-- Feeds the commands one per second starting at start.
local function feed(coach, commands, start)
  for offset, command in ipairs(commands) do
    coach:observe(command, start + offset - 1)
  end
end

local four_j = { "j", "j", "j", "j", "w" }

describe("Coach", function()
  it("stays quiet while no tip matches", function()
    local notifier = fake_notifier()
    feed(new_coach(notifier), { "j", "j", "j", "w" }, 1000)
    expect(notifier.shown):to_equal({})
  end)

  it("shows the tip the moment the habit happens", function()
    local notifier = fake_notifier()
    local coach = new_coach(notifier)
    feed(coach, { "j", "j", "j" }, 1000)
    expect(coach:observe("j", 1003).id):to_be("repeated-j")
    expect(notifier.shown):to_equal({ "repeated-j" })
  end)

  it("waits for more runs when the threshold is higher", function()
    local notifier = fake_notifier()
    local coach = new_coach(notifier, { threshold = 2 })
    feed(coach, four_j, 1000)
    expect(notifier.shown):to_equal({})
    feed(coach, four_j, 1010)
    expect(notifier.shown):to_equal({ "repeated-j" })
  end)

  it("does not repeat a tip during its cooldown, and does after it", function()
    local notifier = fake_notifier()
    local coach = new_coach(notifier)
    feed(coach, four_j, 1000)
    feed(coach, four_j, 1100)
    feed(coach, four_j, 1700)
    expect(notifier.shown):to_equal({ "repeated-j", "repeated-j" })
  end)

  it("forgets commands older than the window", function()
    local notifier = fake_notifier()
    local coach = new_coach(notifier, { threshold = 2 })
    feed(coach, four_j, 1000)
    feed(coach, four_j, 1100)
    expect(notifier.shown):to_equal({})
  end)

  it("skips a tip that does not apply here", function()
    local notifier = fake_notifier()
    local coach = new_coach(notifier, {
      resolve = function(tip)
        return tip.id ~= "repeated-j" and tip or nil
      end,
    })
    feed(coach, four_j, 1000)
    expect(notifier.shown):to_equal({})
  end)

  it("shows nothing while switched off, but keeps watching", function()
    local notifier = fake_notifier()
    local coach = new_coach(notifier)
    coach:set_enabled(false)
    feed(coach, four_j, 1000)
    coach:set_enabled(true)
    coach:observe("d$", 1005)
    expect(notifier.shown):to_equal({ "repeated-j" })
  end)
end)
