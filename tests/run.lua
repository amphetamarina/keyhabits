-- Runs every tests/*_spec.lua and exits non-zero on any failure. Run with
-- `nvim --headless --clean -l tests/run.lua`, as `make test` does.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
package.path = root .. "/tests/?.lua;" .. package.path

local spec = require("spec")

local load_failures = 0
for _, file in ipairs(vim.fn.sort(vim.fn.glob(root .. "/tests/*_spec.lua", false, true))) do
  local ok, err = pcall(dofile, file)
  if not ok then
    load_failures = load_failures + 1
    io.stdout:write(("FAIL %s: %s\n"):format(vim.fn.fnamemodify(file, ":t"), tostring(err)))
  end
end

local tally = spec.summary()
local failed = tally.failed + load_failures
io.stdout:write(("passed: %d failed: %d\n"):format(tally.passed, failed))
os.exit(failed > 0 and 1 or 0)
