-- Options with their defaults. setup(opts) merges the user's options over
-- these and validates the result.

local M = {}

local function default_log_file()
  local data_home = vim.env.XDG_DATA_HOME
  if data_home == nil or data_home == "" then
    data_home = vim.fn.expand("~/.local/share")
  end
  return data_home .. "/keyhabits/events.jsonl"
end

function M.defaults()
  return {
    -- where events are appended; shared with the Vim version's log
    log_file = default_log_file(),
    -- start recording when setup() runs
    auto_start = true,
    -- events buffered before they are written
    flush_threshold = 200,
    -- milliseconds between writes of a partial buffer; 0 disables the timer
    flush_interval = 30000,
    -- record typed text instead of <text>; the log then holds passwords too
    record_text = false,
    report = {
      -- entries shown per ranked section
      limit = 20,
    },
    tips = {
      -- show a tip with vim.notify() the moment a habit happens
      enabled = true,
      -- times a habit must occur within the window before its tip shows
      threshold = 1,
      -- seconds of recent commands watched
      window = 60,
      -- seconds before the same tip may show again
      cooldown = 600,
      -- tip ids never to show, see :KeyHabits tips
      disable = {},
    },
  }
end

local function positive(name, value)
  if type(value) ~= "number" or value < 1 then
    error(("keyhabits: %s must be a number of at least 1"):format(name), 0)
  end
end

function M.merge(opts)
  local config = vim.tbl_deep_extend("force", M.defaults(), opts or {})
  vim.validate("log_file", config.log_file, "string")
  vim.validate("auto_start", config.auto_start, "boolean")
  vim.validate("flush_interval", config.flush_interval, "number")
  vim.validate("record_text", config.record_text, "boolean")
  vim.validate("tips.enabled", config.tips.enabled, "boolean")
  vim.validate("tips.disable", config.tips.disable, "table")
  positive("flush_threshold", config.flush_threshold)
  positive("report.limit", config.report.limit)
  positive("tips.threshold", config.tips.threshold)
  positive("tips.window", config.tips.window)
  positive("tips.cooldown", config.tips.cooldown)
  config.log_file = vim.fn.expand(config.log_file)
  return config
end

return M
