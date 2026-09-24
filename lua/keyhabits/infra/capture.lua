-- Live capture: Neovim's key and state events become recorded events.
-- Buffering belongs to the Recorder; everything here is the glue to Neovim,
-- so the key handler stays cheap.

local event = require("keyhabits.domain.event")
local stats = require("keyhabits.domain.stats")

local M = {}

-- A command ends when Neovim returns to Normal proper; "no"
-- (operator-pending) is not the end of anything.
function M.is_command_end(new_mode)
  return new_mode == "n"
end

-- SafeState only separates plain Normal motions. In other modes it fires
-- after every key and would fragment a command.
function M.is_safe_boundary(mode)
  return mode:sub(1, 1) == "n"
end

-- Plugins that read keys themselves make Neovim report some keys twice.
-- which-key feeds keys back as typed: after "dw" the "w" arrives again, and
-- after "<Space>ul" the three keys are followed by "<Space>ul" as a whole,
-- within a couple of milliseconds. mini.ai's "i" reads the next key, so after
-- "vi" the "w" arrives as "iw". Only what a report adds to the keys already
-- recorded for the command is a key press. An exact repeat counts as a replay
-- only within replay_ns, since nobody types that fast (key repeat is about
-- 30 ms apart) and "dd" is a real repeat.
M.replay_ns = 5e6
local remembered = 8

-- The part of name that is new. recent holds the last keys recorded, oldest
-- first, each { name, at, grp }; only those of the command in group grp
-- count.
function M.new_part(recent, name, grp, now)
  local spelled, longest = "", ""
  for index = #recent, 1, -1 do
    local entry = recent[index]
    if entry.grp ~= grp then
      break
    end
    spelled = entry.name .. spelled
    if #spelled > #name then
      break
    end
    if spelled == name then
      return now - recent[#recent].at <= M.replay_ns and "" or name
    end
    if name:sub(1, #spelled) == spelled then
      longest = spelled
    end
  end
  return name:sub(#longest + 1)
end

local Capture = {}
Capture.__index = Capture

-- options: { recorder, record_text, flush_interval, on_command }. on_command,
-- when given, receives each finished command, e.g. "ciw<text><Esc>".
function M.new(options)
  return setmetatable({
    recorder = options.recorder,
    record_text = options.record_text,
    flush_interval = options.flush_interval,
    on_command = options.on_command,
    running = false,
    session = "",
    group = 0,
    pending = {},
    recent = {},
  }, Capture)
end

function Capture:is_running()
  return self.running
end

-- Takes one event: records it and, while someone listens, keeps it for the
-- command being typed.
function Capture:take(ev)
  self.recorder:record(ev)
  if self.on_command then
    self.pending[#self.pending + 1] = ev
  end
end

-- A boundary: the keys since the last one form a command, if they form one
-- at all. A boundary can fire with no keys since the previous one.
function Capture:next_group()
  self.group = self.group + 1
  if #self.pending == 0 then
    return
  end
  local commands = stats.group_commands(self.pending)
  self.pending = {}
  if #commands > 0 then
    self.on_command(commands[1])
  end
end

-- vim.on_key() passes the key after mappings and the key(s) typed before
-- them. Keys a mapping produces, and keys Neovim generates itself, arrive
-- with nothing typed and are not habits.
function Capture:on_key(key, typed)
  if typed == nil or typed == "" then
    return
  end
  local ev = event.new({
    ts = os.time(),
    sid = self.session,
    grp = self.group,
    mode = vim.api.nvim_get_mode().mode,
    key = key,
    typed = typed,
    ft = vim.bo.filetype,
  }, self.record_text)
  local now = vim.uv.hrtime()
  ev.typed = M.new_part(self.recent, ev.typed, self.group, now)
  if ev.typed == "" then
    return
  end
  self.recent[#self.recent + 1] = { name = ev.typed, at = now, grp = self.group }
  if #self.recent > remembered then
    table.remove(self.recent, 1)
  end
  self:take(ev)
end

function Capture:start()
  if self.running then
    return
  end
  self.running = true
  self.session = ("%d-%d"):format(vim.fn.getpid(), os.time())
  self.group = 0
  self.namespace = vim.on_key(function(key, typed)
    self:on_key(key, typed)
  end, self.namespace)
  self.augroup = vim.api.nvim_create_augroup("keyhabits", { clear = true })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = self.augroup,
    -- ModeChanged matches "old_mode:new_mode".
    callback = function(args)
      if M.is_command_end(args.match:match(":(.*)$")) then
        self:next_group()
      end
    end,
  })
  vim.api.nvim_create_autocmd("SafeState", {
    group = self.augroup,
    callback = function()
      if M.is_safe_boundary(vim.api.nvim_get_mode().mode) then
        self:next_group()
      end
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = self.augroup,
    callback = function()
      self.recorder:flush()
    end,
  })
  if self.flush_interval > 0 then
    self.timer = vim.uv.new_timer()
    self.timer:start(
      self.flush_interval,
      self.flush_interval,
      vim.schedule_wrap(function()
        self.recorder:flush()
      end)
    )
  end
end

function Capture:stop()
  if not self.running then
    return
  end
  self.recorder:flush()
  vim.on_key(nil, self.namespace)
  vim.api.nvim_del_augroup_by_id(self.augroup)
  if self.timer then
    self.timer:stop()
    self.timer:close()
    self.timer = nil
  end
  self.pending = {}
  self.running = false
end

return M
