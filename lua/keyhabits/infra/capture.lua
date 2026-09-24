-- Live capture: Neovim's key and state events become recorded events.
-- Buffering belongs to the Recorder; everything here is the glue to Neovim,
-- so the key handler stays cheap.

local event = require("keyhabits.domain.event")

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
-- which-key feeds keys back as typed, within a couple of milliseconds: after
-- "dw" the "w" arrives again, after "<Space>ul" the three keys are followed by
-- "<Space>ul" as a whole, and after "<C-W>j" the keys come again one by one.
-- mini.ai's "i" reads the next key, so after "vi" the "w" arrives as "iw".
-- Only what a report adds to the keys already recorded for the command is a
-- key press. A repeat counts as a replay only within replay_ns, since nobody
-- types that fast (key repeat is about 30 ms apart) and "dd" is a real repeat.
M.replay_ns = 5e6
local remembered = 8

function M.new_keys()
  return { recent = {}, replay = nil }
end

local function command_keys(keys, grp)
  local found = {}
  for _, entry in ipairs(keys.recent) do
    if entry.grp == grp then
      found[#found + 1] = entry
    end
  end
  return found
end

-- The keys of the command, again from its first one, each within replay_ns
-- of the one before.
local function continues_replay(keys, command, name, now)
  local replay = keys.replay
  if replay and now - replay.at <= M.replay_ns and command[replay.next] and command[replay.next].name == name then
    replay.next = replay.next + 1
    replay.at = now
    return true
  end
  keys.replay = nil
  if #command >= 2 and command[1].name == name and now - command[#command].at <= M.replay_ns then
    keys.replay = { next = 2, at = now }
    return true
  end
  return false
end

-- The part of name that is new. keys holds the last keys recorded, oldest
-- first, each { name, at, grp }, and any replay under way; only the keys of
-- the command in group grp count. Remembers name when it adds something.
function M.new_part(keys, name, grp, now)
  local command = command_keys(keys, grp)
  if continues_replay(keys, command, name, now) then
    return ""
  end
  local spelled, longest = "", ""
  for index = #command, 1, -1 do
    spelled = command[index].name .. spelled
    if #spelled > #name then
      break
    end
    if spelled == name then
      if now - command[#command].at <= M.replay_ns then
        return ""
      end
      break
    end
    if name:sub(1, #spelled) == spelled then
      longest = spelled
    end
  end
  local part = name:sub(#longest + 1)
  keys.recent[#keys.recent + 1] = { name = part, at = now, grp = grp }
  if #keys.recent > remembered then
    table.remove(keys.recent, 1)
  end
  return part
end

local Capture = {}
Capture.__index = Capture

-- options: { recorder, record_text, flush_interval }
function M.new(options)
  return setmetatable({
    recorder = options.recorder,
    record_text = options.record_text,
    flush_interval = options.flush_interval,
    running = false,
    session = "",
    group = 0,
    keys = M.new_keys(),
  }, Capture)
end

function Capture:is_running()
  return self.running
end

-- A boundary: the keys after it belong to the next command.
function Capture:next_group()
  self.group = self.group + 1
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
  ev.typed = M.new_part(self.keys, ev.typed, self.group, now)
  if ev.typed ~= "" then
    self.recorder:record(ev)
  end
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
  self.running = false
end

return M
