-- The Recorder use case: buffer events in memory and hand them to a store in
-- batches. It never touches autocommands, timers or files, so it is tested
-- with the memory store.
--
-- A store is any table with append(events), read_all() and clear().

local Recorder = {}
Recorder.__index = Recorder

function Recorder.new(store, threshold)
  if threshold < 1 then
    error("keyhabits.recorder: the flush threshold must be at least 1", 0)
  end
  return setmetatable({ store = store, threshold = threshold, buffer = {} }, Recorder)
end

function Recorder:record(event)
  self.buffer[#self.buffer + 1] = event
  if #self.buffer >= self.threshold then
    self:flush()
  end
end

function Recorder:flush()
  if #self.buffer == 0 then
    return
  end
  local events = self.buffer
  self.buffer = {}
  self.store:append(events)
end

return Recorder
