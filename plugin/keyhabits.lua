-- Defines :KeyHabits. Recording starts when setup() runs, which a LazyVim
-- spec with opts does on its own.

if vim.g.loaded_keyhabits then
  return
end
vim.g.loaded_keyhabits = true

vim.api.nvim_create_user_command("KeyHabits", function(opts)
  require("keyhabits").command(opts)
end, {
  nargs = "*",
  bang = true,
  desc = "keyhabits: report, start, stop, clear",
  complete = function(arg_lead, cmd_line)
    if #vim.split(cmd_line, "%s+") > 2 then
      return {}
    end
    local names = vim.tbl_keys(require("keyhabits").subcommands)
    table.sort(names)
    return vim.tbl_filter(function(name)
      return vim.startswith(name, arg_lead)
    end, names)
  end,
})
