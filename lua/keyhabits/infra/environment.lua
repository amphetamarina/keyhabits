-- What the tip selection needs to know about this Neovim: which plugins are
-- installed and which keys are mapped to something else.

local M = {}

-- A plugin counts when lazy.nvim knows it, loaded or not, since lazy
-- loading means a plugin such as flash.nvim may only load on its first key.
-- Without lazy.nvim, a plugin counts when its Lua module can be found.
local modules = {
  ["flash.nvim"] = "flash",
  ["mini.ai"] = "mini.ai",
}

function M.has(plugin)
  local ok, lazy_config = pcall(require, "lazy.core.config")
  if ok and lazy_config.plugins and lazy_config.plugins[plugin] then
    return true
  end
  local module = modules[plugin] or plugin
  if package.loaded[module] then
    return true
  end
  return vim.api.nvim_get_runtime_file("lua/" .. module:gsub("%.", "/") .. "*", false)[1] ~= nil
end

-- A mapping changes what a key does when it has a description, as mappings
-- from plugins and LazyVim do, and does not simply run the key itself: s for
-- flash.nvim or H for the previous buffer do, j mapped to "v:count == 0 ?
-- 'gj' : 'j'" does not. Returns the description of such a mapping.
function M.remapped(mode, key)
  local mapping = vim.fn.maparg(key, mode, false, true)
  if vim.tbl_isempty(mapping) or not mapping.desc or mapping.desc == "" then
    return nil
  end
  if mapping.callback or not (mapping.rhs or ""):find(key, 1, true) then
    return mapping.desc
  end
  return nil
end

-- The environment the selection works with: this editor, and the tips the
-- user switched off.
function M.current(disable)
  local disabled = {}
  for _, id in ipairs(disable) do
    disabled[id] = true
  end
  return { has = M.has, remapped = M.remapped, disabled = disabled }
end

return M
