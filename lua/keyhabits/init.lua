-- The composition root: setup(opts) builds the object graph from the options,
-- and the functions below are what :KeyHabits and a LazyVim spec call.
-- Nothing else knows which store is used.

local JsonlStore = require("keyhabits.infra.jsonl_store")
local Recorder = require("keyhabits.app.recorder")
local capture = require("keyhabits.infra.capture")
local config = require("keyhabits.config")
local report_view = require("keyhabits.infra.report_view")
local reporter = require("keyhabits.app.reporter")

local M = {}

local state = nil

local function build(opts)
  local settings = config.merge(opts)
  local store = JsonlStore.new(settings.log_file)
  return {
    config = settings,
    store = store,
    capture = capture.new({
      recorder = Recorder.new(store, settings.flush_threshold),
      record_text = settings.record_text,
      flush_interval = settings.flush_interval,
    }),
  }
end

local function ensure()
  if not state then
    M.setup()
  end
  return assert(state)
end

function M.setup(opts)
  if state then
    state.capture:stop()
  end
  state = build(opts)
  if state.config.auto_start then
    state.capture:start()
  end
end

function M.start()
  ensure().capture:start()
end

function M.stop()
  ensure().capture:stop()
end

function M.is_recording()
  return state ~= nil and state.capture:is_running()
end

function M.log_file()
  return ensure().store.path
end

-- Opens the report; days limits it to the last days, 0 or nil is everything.
function M.report(days)
  local s = ensure()
  s.capture.recorder:flush()
  local events = s.store:read_all()
  if s.store.skipped > 0 then
    vim.notify(("keyhabits: skipped %d unreadable lines"):format(s.store.skipped), vim.log.levels.WARN)
  end
  local report = reporter.build(events, {
    limit = s.config.report.limit,
    since = (days or 0) > 0 and os.time() - days * 86400 or 0,
  })
  report_view.open(report_view.render(report))
end

function M.clear(force)
  local s = ensure()
  s.capture:stop()
  if not force and vim.fn.confirm("Delete the keyhabits log?", "&Yes\n&No", 2) ~= 1 then
    vim.notify("keyhabits: log kept", vim.log.levels.INFO)
    return
  end
  s.store:clear()
  vim.notify("keyhabits: cleared " .. s.store.path, vim.log.levels.INFO)
end

M.subcommands = {
  report = function(args)
    M.report(tonumber(args[1]))
  end,
  start = M.start,
  stop = M.stop,
  clear = function(_, bang)
    M.clear(bang)
  end,
}

-- :KeyHabits {subcommand} [args]; with no subcommand, the report.
function M.command(opts)
  local name = opts.fargs[1] or "report"
  local run = M.subcommands[name]
  if not run then
    vim.notify("keyhabits: unknown subcommand " .. name, vim.log.levels.ERROR)
    return
  end
  run(vim.list_slice(opts.fargs, 2), opts.bang)
end

return M
