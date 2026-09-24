-- The Event value object: one key press.
--
-- A recorded event has exactly seven fields. Keys are stored with readable
-- names ("<Esc>", "<Space>") by keytrans(), and text typed in Insert,
-- Replace, Command-line and Terminal modes is replaced by a placeholder, so
-- that counts and rhythm survive while content does not.

local M = {}

M.PLACEHOLDER = "<text>"

local field_types = {
  ts = "number",
  sid = "string",
  grp = "number",
  mode = "string",
  key = "string",
  typed = "string",
  ft = "string",
}

local printable = vim.regex([=[^[[:print:]]\+$]=])

-- Insert, Replace, Command-line and Terminal families of the mode.
local function is_text_mode(mode)
  return mode ~= "" and ("iRct"):find(mode:sub(1, 1), 1, true) ~= nil
end

-- Printable characters are the user's text; anything else (Esc, Tab, CR, BS,
-- arrows, Ctrl combinations) is a key to be kept verbatim. A mapping's
-- left-hand side arrives as several characters at once and counts as text
-- when all of them are printable.
local function is_text(raw)
  return raw ~= "" and printable:match_str(raw) ~= nil
end

local function mask(raw, mode)
  if is_text_mode(mode) and is_text(raw) then
    return M.PLACEHOLDER
  end
  return raw
end

-- keytrans() the raw key, unless it was masked: the placeholder must not be
-- translated ("<text>" would become "<lt>text>"). Masking has to happen on
-- the raw key, because keytrans() turns a typed "<" into "<lt>" and a space
-- into "<Space>", making both look like special keys.
local function key_name(raw, mode, record_text)
  local masked = record_text and raw or mask(raw, mode)
  if masked == M.PLACEHOLDER then
    return masked
  end
  return vim.fn.keytrans(raw)
end

-- raw holds ts, sid, grp, mode, ft and the raw keycodes key and typed, as
-- vim.on_key() passes them.
function M.new(raw, record_text)
  return {
    ts = raw.ts,
    sid = raw.sid,
    grp = raw.grp,
    mode = raw.mode,
    key = key_name(raw.key, raw.mode, record_text),
    typed = key_name(raw.typed, raw.mode, record_text),
    ft = raw.ft,
  }
end

function M.encode(event)
  return vim.json.encode(event)
end

local function problem(detail)
  return "keyhabits.event: " .. detail
end

local function validate(event)
  for name, want in pairs(field_types) do
    if event[name] == nil then
      error(problem("missing field " .. name), 0)
    end
    if type(event[name]) ~= want then
      error(problem(("field %s must be a %s but is a %s"):format(name, want, type(event[name]))), 0)
    end
  end
  for name in pairs(event) do
    if not field_types[name] then
      error(problem("unknown field " .. name), 0)
    end
  end
end

-- Rejects a malformed line by throwing, never by returning partial data.
function M.decode(line)
  local ok, decoded = pcall(vim.json.decode, line)
  if not ok then
    error(problem("not valid JSON: " .. tostring(decoded)), 0)
  end
  if type(decoded) ~= "table" or vim.islist(decoded) and next(decoded) ~= nil then
    error(problem("expected a JSON object but got " .. type(decoded)), 0)
  end
  validate(decoded)
  return decoded
end

return M
