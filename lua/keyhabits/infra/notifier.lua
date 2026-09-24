-- Shows a tip with vim.notify(), which LazyVim hands to its notifier (noice
-- or snacks), and remembers the last one for :KeyHabits why.

local Notifier = {}
Notifier.__index = Notifier

function Notifier.new()
  return setmetatable({ last = nil }, Notifier)
end

function Notifier.message(tip)
  local source = tip.source and (" (" .. tip.source .. ")") or ""
  return ("%s%s\n:help %s"):format(tip.tip, source, tip.help)
end

function Notifier:notify(tip)
  self.last = tip
  -- The tip is found while a key is being handled; showing it is left to the
  -- main loop so the notifier can draw.
  vim.schedule(function()
    vim.notify(Notifier.message(tip), vim.log.levels.INFO, { title = "keyhabits", id = "keyhabits" })
  end)
end

return Notifier
