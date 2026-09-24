-- Renders a Report as text and shows it in a floating window. On an Advice
-- line, <CR> opens the :help the tip comes from.

local stats = require("keyhabits.domain.stats")

local M = {}

M.advice_title = "Advice (keys a better command would have saved)"
M.untipped_title = "Repeated, no tip yet (presses in runs of 3 or more)"

local mode_labels = {
  n = "Normal",
  i = "Insert",
  v = "Visual",
  V = "Visual",
  ["\22"] = "Visual",
  c = "Command-line",
  R = "Replace",
  t = "Terminal",
}

local function mode_rows(rows)
  local counts = {}
  for _, row in ipairs(rows) do
    local label = mode_labels[row[1]:sub(1, 1)] or row[1]:sub(1, 1)
    counts[label] = (counts[label] or 0) + row[2]
  end
  return stats.top(counts, 0)
end

local function stamp(ts)
  return os.date("%Y-%m-%d %H:%M", ts)
end

local function section(lines, title, rows)
  lines[#lines + 1] = ""
  lines[#lines + 1] = title
  if #rows == 0 then
    lines[#lines + 1] = "  (none)"
    return
  end
  for _, row in ipairs(rows) do
    lines[#lines + 1] = ("%6d  %s"):format(row[2], row[1])
  end
end

-- The lines of the report, and for each Advice line the help tag it cites,
-- by line number.
function M.render(report)
  local lines = { "keyhabits report" }
  local help_at = {}
  if report.total_keys == 0 then
    lines[#lines + 1] = "no events recorded"
    return lines, help_at
  end
  lines[#lines + 1] = ("from %s to %s"):format(stamp(report.time_span[1]), stamp(report.time_span[2]))
  lines[#lines + 1] = ("keys: %d  sessions: %d"):format(report.total_keys, report.sessions)
  lines[#lines + 1] = ""
  lines[#lines + 1] = M.advice_title
  if #report.advice == 0 then
    lines[#lines + 1] = "  (none)"
  end
  for _, row in ipairs(report.advice) do
    local source = row.source and (" [" .. row.source .. "]") or ""
    lines[#lines + 1] = ("%6d  %s%s  (:help %s)"):format(row.saved, row.tip, source, row.help)
    help_at[#lines] = row.help
  end
  section(lines, M.untipped_title, report.untipped)
  section(lines, "Top keys", report.top_keys)
  section(lines, "Top commands", report.top_commands)
  section(lines, "Top key pairs", report.top_bigrams)
  section(lines, "Modes", mode_rows(report.modes))
  section(lines, "Filetypes", report.filetypes)
  return lines, help_at
end

local function highlight(buf, lines, help_at)
  local ns = vim.api.nvim_create_namespace("keyhabits-report")
  for index, line in ipairs(lines) do
    if index == 1 or line:match("^%u") then
      vim.api.nvim_buf_set_extmark(buf, ns, index - 1, 0, { end_col = #line, hl_group = "Title" })
    end
    if help_at[index] then
      local start = line:find("(:help", 1, true)
      vim.api.nvim_buf_set_extmark(buf, ns, index - 1, start - 1, { end_col = #line, hl_group = "Comment" })
    end
  end
end

-- Opens the lines in a centred float; q closes it and <CR> on an Advice line
-- opens the tip's help.
function M.open(lines, help_at)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "keyhabits"
  highlight(buf, lines, help_at)
  local width = math.min(math.floor(vim.o.columns * 0.8), 110)
  local height = math.min(math.floor(vim.o.lines * 0.8), #lines)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = math.max(height, 1),
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " keyhabits ",
    title_pos = "center",
  })
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close the report" })
  vim.keymap.set("n", "<CR>", function()
    local tag = help_at[vim.api.nvim_win_get_cursor(0)[1]]
    if tag then
      vim.cmd.close()
      vim.cmd.help(tag)
    end
  end, { buffer = buf, desc = "Open the tip's help" })
  return buf, win
end

return M
