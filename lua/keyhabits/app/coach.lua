-- The Coach use case: live tips. It watches the commands of the last few
-- seconds and, when one tip keeps matching, hands the tip to the notifier.
-- Time comes in with every command, so nothing here reads a clock, and the
-- notifier is any table with notify(tip).

local advice = require("keyhabits.domain.advice")

-- Matching runs after every command, so the window is also capped in size.
local max_recent = 50

local Coach = {}
Coach.__index = Coach

-- options: { notifier, tips, resolve, threshold, window, cooldown }.
-- resolve(tip) returns the tip as shown here, or nil when it does not apply;
-- it is asked at the moment a tip is due, so mappings made after startup
-- count.
function Coach.new(options)
  return setmetatable({
    notifier = options.notifier,
    tips = options.tips,
    resolve = options.resolve,
    threshold = options.threshold,
    window = options.window,
    cooldown = options.cooldown,
    enabled = true,
    recent = {},
    shown_at = {},
  }, Coach)
end

function Coach:set_enabled(enabled)
  self.enabled = enabled
end

function Coach:forget(now)
  local kept = {}
  for _, entry in ipairs(self.recent) do
    if now - entry.ts < self.window then
      kept[#kept + 1] = entry
    end
  end
  if #kept > max_recent then
    kept = vim.list_slice(kept, #kept - max_recent + 1)
  end
  self.recent = kept
end

function Coach:is_due(id, runs, now)
  if runs < self.threshold then
    return false
  end
  return self.shown_at[id] == nil or now - self.shown_at[id] >= self.cooldown
end

-- Takes one finished command. Shows at most one tip: the first, in catalogue
-- order, that reached the threshold, is not cooling down and applies here.
-- Returns the tip shown, if any.
function Coach:observe(command, now)
  self.recent[#self.recent + 1] = { ts = now, command = command }
  self:forget(now)
  if not self.enabled then
    return nil
  end
  local commands = {}
  for index, entry in ipairs(self.recent) do
    commands[index] = entry.command
  end
  local found = advice.match(commands, self.tips)
  for _, tip in ipairs(self.tips) do
    local tally = found[tip.id]
    if tally and self:is_due(tip.id, tally.runs, now) then
      local shown = self.resolve(tip)
      if shown then
        self.shown_at[tip.id] = now
        self.notifier:notify(shown)
        return shown
      end
    end
  end
  return nil
end

return Coach
