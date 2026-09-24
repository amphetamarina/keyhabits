-- Which tips apply in this editor. Pure: the environment comes in as an
-- object answering three questions, so the rules can be tested without
-- plugins or mappings.
--
-- env.has(plugin)          -> true when the plugin is installed
-- env.remapped(mode, key)  -> a description when the key is mapped to
--                             something else in that mode, else nil
-- env.disabled             -> set of tip ids the user switched off

local M = {}

-- "i:<C-W>" is <C-W> in Insert mode, "x:>" is > in Visual mode, and a bare
-- key is a Normal mode key.
local function split_key(suggestion)
  local mode, key = suggestion:match("^([ix]):(.+)$")
  if mode then
    return mode, key
  end
  return "n", suggestion
end

local function first_variant(tip, env)
  for _, variant in ipairs(tip.variants or {}) do
    if env.has(variant.requires) then
      return variant
    end
  end
end

-- The tip as it should be shown here, or nil and the reason it is not.
function M.resolve(tip, env)
  if env.disabled[tip.id] then
    return nil, "switched off in setup()"
  end
  if tip.requires and not env.has(tip.requires) then
    return nil, "needs " .. tip.requires
  end
  local shown = tip
  local variant = first_variant(tip, env)
  if variant then
    shown = vim.tbl_extend("force", tip, {
      tip = variant.tip,
      help = variant.help,
      suggests = variant.suggests,
      source = variant.requires,
    })
  end
  for _, suggestion in ipairs(shown.suggests) do
    local mode, key = split_key(suggestion)
    local mapping = env.remapped(mode, key)
    if mapping then
      return nil, ("%s is mapped to %q in your config"):format(key, mapping)
    end
  end
  return shown
end

-- Splits a catalogue into the tips shown here and the ones left out, each
-- left-out one with its reason.
function M.split(tips, env)
  local active, skipped = {}, {}
  for _, tip in ipairs(tips) do
    local shown, reason = M.resolve(tip, env)
    if shown then
      active[#active + 1] = shown
    else
      skipped[#skipped + 1] = { tip = tip, reason = reason }
    end
  end
  return active, skipped
end

return M
