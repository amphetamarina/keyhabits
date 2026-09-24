-- Shows a tip with vim.notify(), which LazyVim hands to its notifier (noice
-- or snacks), and remembers the last one for :KeyHabits why.

local Notifier = {}
Notifier.__index = Notifier

function Notifier.new()
  return setmetatable({ last = nil }, Notifier)
end

-- snacks and nvim-notify make a notification at most 40% of the screen wide
-- and cut longer lines, so the message is wrapped to fit inside that.
function Notifier.width()
  return math.max(30, math.min(60, math.floor(vim.o.columns * 0.4) - 4))
end

local function wrap(text, width)
  local lines, line = {}, ""
  for word in text:gmatch("%S+") do
    if line ~= "" and vim.fn.strdisplaywidth(line .. " " .. word) > width then
      lines[#lines + 1] = line
      line = word
    else
      line = line == "" and word or (line .. " " .. word)
    end
  end
  if line ~= "" then
    lines[#lines + 1] = line
  end
  return lines
end

-- The tip, wrapped to width, then where it comes from and its help.
function Notifier.message(tip, width)
  width = width or Notifier.width()
  local lines = wrap(tip.tip, width)
  local footer = (tip.source and (tip.source .. " · ") or "") .. ":help " .. tip.help
  vim.list_extend(lines, wrap(footer, width))
  return table.concat(lines, "\n")
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
