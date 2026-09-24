-- An event store kept in memory, for specs and dry runs.

local MemoryStore = {}
MemoryStore.__index = MemoryStore

function MemoryStore.new()
  return setmetatable({ events = {}, appends = 0 }, MemoryStore)
end

function MemoryStore:append(events)
  self.appends = self.appends + 1
  vim.list_extend(self.events, events)
end

function MemoryStore:read_all()
  return vim.deepcopy(self.events)
end

function MemoryStore:clear()
  self.events = {}
end

return MemoryStore
