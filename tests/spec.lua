-- A small BDD DSL for the keyhabits specs: describe, it and expect.

local M = {}

local passed, failed, depth = 0, 0, 0

local function say(line)
  io.stdout:write(line, "\n")
end

local function pad()
  return ("  "):rep(depth)
end

function M.describe(name, body)
  say(pad() .. name)
  depth = depth + 1
  local ok, err = pcall(body)
  depth = depth - 1
  if not ok then
    failed = failed + 1
    say(pad() .. "FAIL " .. name .. ": " .. tostring(err))
  end
end

function M.it(name, body)
  local ok, err = pcall(body)
  if ok then
    passed = passed + 1
    say(pad() .. "ok " .. name)
  else
    failed = failed + 1
    say(pad() .. "FAIL " .. name .. ": " .. tostring(err))
  end
end

local Expectation = {}
Expectation.__index = Expectation

local function fail(message)
  error("expect: " .. message, 3)
end

function Expectation:to_equal(expected)
  if not vim.deep_equal(self.actual, expected) then
    fail(("expected %s but got %s"):format(vim.inspect(expected), vim.inspect(self.actual)))
  end
end

function Expectation:to_be(expected)
  if self.actual ~= expected then
    fail(("expected %s but got %s"):format(vim.inspect(expected), vim.inspect(self.actual)))
  end
end

function Expectation:to_be_true()
  self:to_be(true)
end

function Expectation:to_be_false()
  self:to_be(false)
end

function Expectation:to_be_nil()
  self:to_be(nil)
end

function Expectation:to_have_length(length)
  if #self.actual ~= length then
    fail(("expected length %d but got %d: %s"):format(length, #self.actual, vim.inspect(self.actual)))
  end
end

function Expectation:to_contain(part)
  if type(self.actual) == "string" then
    if not self.actual:find(part, 1, true) then
      fail(("expected %q to contain %q"):format(self.actual, part))
    end
    return
  end
  if not vim.tbl_contains(self.actual, part) then
    fail(("expected %s to contain %s"):format(vim.inspect(self.actual), vim.inspect(part)))
  end
end

-- The function must throw an error whose message contains part.
function Expectation:to_throw(part)
  local ok, err = pcall(self.actual)
  if ok then
    fail("expected an error but nothing was thrown")
  end
  if not tostring(err):find(part, 1, true) then
    fail(("expected an error containing %q but got %q"):format(part, tostring(err)))
  end
end

function M.expect(actual)
  return setmetatable({ actual = actual }, Expectation)
end

function M.summary()
  return { passed = passed, failed = failed }
end

return M
