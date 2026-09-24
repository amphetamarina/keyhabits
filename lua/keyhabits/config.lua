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
  positive("flush_threshold", config.flush_threshold)
  positive("report.limit", config.report.limit)
  config.log_file = vim.fn.expand(config.log_file)
  return config
end

return M
