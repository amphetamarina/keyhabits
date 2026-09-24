-- The composition root: setup(opts) builds the object graph from the options,
-- and the functions below are what :KeyHabits and a LazyVim spec call.
-- Nothing else knows which store, notifier or environment is used.

local Coach = require("keyhabits.app.coach")
local Notifier = require("keyhabits.infra.notifier")
local Recorder = require("keyhabits.app.recorder")
local JsonlStore = require("keyhabits.infra.jsonl_store")
local capture = require("keyhabits.infra.capture")
local config = require("keyhabits.config")
local environment = require("keyhabits.infra.environment")
local reporter = require("keyhabits.app.reporter")
local report_view = require("keyhabits.infra.report_view")
local selection = require("keyhabits.app.selection")
local tips = require("keyhabits.domain.tips")

local M = {}

local state = nil

-- The environment is read on every call, so mappings and plugins that load
-- after startup are taken into account.
local function resolver(disable)
  return function(tip)
    return selection.resolve(tip, environment.current(disable))
  end
end

local function build(opts)
  local settings = config.merge(opts)
  local store = JsonlStore.new(settings.log_file)
  local notifier = Notifier.new()
  local built = { config = settings, store = store, notifier = notifier }
  built.coach = Coach.new({
    notifier = notifier,
    tips = tips,
    resolve = resolver(settings.tips.disable),
    threshold = settings.tips.threshold,
    window = settings.tips.window,
    cooldown = settings.tips.cooldown,
  })
  built.coach:set_enabled(settings.tips.enabled)
  built.capture = capture.new({
    recorder = Recorder.new(store, settings.flush_threshold),
    record_text = settings.record_text,
    flush_interval = settings.flush_interval,
    on_command = function(command)
      -- A macro being recorded or replayed is deliberate repetition.
      if vim.fn.reg_recording() == "" and vim.fn.reg_executing() == "" then
        built.coach:observe(command, os.time())
      end
    end,
  })
  return built
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

function M.tips_enabled()
  return state ~= nil and state.coach.enabled
end

function M.set_tips(enabled)
  ensure().coach:set_enabled(enabled)
end

function M.toggle_tips()
  M.set_tips(not M.tips_enabled())
  vim.notify("keyhabits: tips " .. (M.tips_enabled() and "on" or "off"), vim.log.levels.INFO)
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
    tips = tips,
    resolve = resolver(s.config.tips.disable),
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

-- The last tip shown, or nil; for a statusline, say.
function M.last_tip()
  return state and state.notifier.last
end

-- Opens the help for the last tip shown.
function M.why()
  local last = M.last_tip()
  if not last then
    vim.notify("keyhabits: no tip shown yet", vim.log.levels.INFO)
    return
  end
  vim.cmd.help(last.help)
end

-- The catalogue as it applies here: tips shown and tips left out with why.
function M.catalogue()
  local s = ensure()
  return selection.split(tips, environment.current(s.config.tips.disable))
end

function M.show_catalogue()
  local active, skipped = M.catalogue()
  local lines = { ("%d tips active, %d left out"):format(#active, #skipped), "" }
  for _, tip in ipairs(active) do
    local source = tip.source and (" [" .. tip.source .. "]") or ""
    lines[#lines + 1] = ("  %-28s %s%s"):format(tip.id, tip.tip, source)
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Left out"
  for _, entry in ipairs(skipped) do
    lines[#lines + 1] = ("  %-28s %s"):format(entry.tip.id, entry.reason)
  end
  report_view.open(lines, {})
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
  why = M.why,
  tips = M.show_catalogue,
  toggle = M.toggle_tips,
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
