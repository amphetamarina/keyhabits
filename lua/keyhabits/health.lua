-- :checkhealth keyhabits

local M = {}

function M.check()
  local health = vim.health
  local keyhabits = require("keyhabits")

  health.start("keyhabits")
  if vim.fn.has("nvim-0.11") == 1 then
    health.ok("Neovim " .. tostring(vim.version()))
  else
    health.error("Neovim 0.11 or newer is needed (vim.on_key with typed keys)")
  end

  if keyhabits.is_recording() then
    health.ok("recording")
  else
    health.warn("not recording", { "Call require('keyhabits').setup() or run :KeyHabits start" })
  end

  local path = keyhabits.log_file()
  local dir = vim.fn.fnamemodify(path, ":h")
  if vim.fn.filewritable(dir) == 2 or vim.fn.isdirectory(dir) == 0 then
    local size = vim.fn.getfsize(path)
    health.ok(("log: %s (%s)"):format(path, size >= 0 and (size .. " bytes") or "not written yet"))
  else
    health.error("cannot write the log directory " .. dir)
  end

  health.start("keyhabits tips")
  if keyhabits.tips_enabled() then
    health.ok("live tips on")
  else
    health.info("live tips off; :KeyHabits toggle turns them on")
  end
  local active, skipped = keyhabits.catalogue()
  health.ok(("%d tips active"):format(#active))
  for _, entry in ipairs(skipped) do
    health.info(("%s left out: %s"):format(entry.tip.id, entry.reason))
  end
end

return M
