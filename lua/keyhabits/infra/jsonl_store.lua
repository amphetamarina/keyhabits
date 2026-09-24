-- An event store backed by an append-only JSONL file: one encoded event per
-- line. A line that cannot be decoded is skipped and counted, never fatal.

local event = require("keyhabits.domain.event")

local JsonlStore = {}
JsonlStore.__index = JsonlStore

function JsonlStore.new(path)
  return setmetatable({ path = path, skipped = 0 }, JsonlStore)
end

function JsonlStore:append(events)
  local lines = {}
  for index, ev in ipairs(events) do
    lines[index] = event.encode(ev)
  end
  vim.fn.mkdir(vim.fn.fnamemodify(self.path, ":h"), "p")
  vim.fn.writefile(lines, self.path, "a")
end

function JsonlStore:read_all()
  self.skipped = 0
  if vim.fn.filereadable(self.path) == 0 then
    return {}
  end
  local events = {}
  for line in io.lines(self.path) do
    if line ~= "" then
      local ok, decoded = pcall(event.decode, line)
      if ok then
        events[#events + 1] = decoded
      else
        self.skipped = self.skipped + 1
      end
    end
  end
  return events
end

function JsonlStore:clear()
  vim.fn.delete(self.path)
end

return JsonlStore
