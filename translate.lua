-- Vim and LiteXL implement some basic translations a bit differnetly.
-- This file contains functions that implement the correct Vim behaviour. 

local constants = require "plugins.vimxl.constants"

-- Currently only used to forward prev_char next_char. 
-- TODO: Maybe reimplement and drop the dependency? We want clamping anyway...
local doc_translate = require "core.doc.translate"

-- Used for non_word_chars
local config = require "core.config"

---@param char string
local function is_non_word(char)
  return config.non_word_chars:find(char, nil, true) ~= nil
end

---@param char string
local function is_whitespace(char)
  return constants.WHITESPACE:find(char, nil, true) ~= nil
end

---@param char string
local function classify_type(char)
  if is_whitespace(char) then
    return 1
  elseif is_non_word(char) then
    return 2
  else
    return 3
  end
end

-- Collection of translations implementing Vim-specific behaviour.
-- Keep in mind that it contains both what we in the Vim world would call
-- motions as well as text objects, in one table.
local vim_translate = {}

---@type vimxl.motion
function vim_translate.start_of_doc_or_line(_, _, col, _, numerical_argument)
  if numerical_argument ~= nil and numerical_argument > 0 then
    return numerical_argument, col
  else
    return 1, col
  end
end

---Don't call directly.
---@param doc core.doc
---@param line number
---@param col number
---@param continue_to_next_line boolean
local function translate_next_word_start_impl(doc, line, col, continue_to_next_line)
  -- Correctly emulate the w command from Vim. It will
  -- stop on non-whitespace non-words. Then skip to the next word.
  -- If it has to line wrap then it will skip to the first
  -- non-whitespace on that line.

  local last_col = #doc.lines[line]
  local initial_is_non_word = is_non_word(doc:get_char(line, col))
  local stop_on_any_non_whitespace = false
  while col < last_col do
    col = col + 1
    local col_value = doc:get_char(line, col)

    if is_whitespace(col_value) then
      -- From here on: stop at first word.
      stop_on_any_non_whitespace = true
    elseif stop_on_any_non_whitespace or initial_is_non_word ~= is_non_word(col_value) then
      return line, col
    end
  end

  if not continue_to_next_line then
    return line, last_col
  end

  -- On the next line, continue until we have non-whitespace.
  line = line + 1
  col = 0
  last_col = #doc.lines[line]
  while col < last_col do
    col = col + 1
    if not is_whitespace(doc:get_char(line, col)) then
      return line, col
    end
  end

  -- Just a default in case the next line was empty or contains only whitespace.
  return line, 0
end

---@type vimxl.motion
function vim_translate.next_word_start(doc, line, col, _, numerical_argument)
  if numerical_argument == nil or numerical_argument < 1 then numerical_argument = 1 end
  for _ = 1, numerical_argument do
    line, col = translate_next_word_start_impl(doc, line, col, false)
  end
  return line, col

end

---@type vimxl.motion
function vim_translate.next_word_start_multiline(doc, line, col, _, numerical_argument)
  if numerical_argument == nil or numerical_argument < 1 then numerical_argument = 1 end
  for _ = 1, numerical_argument do
    line, col = translate_next_word_start_impl(doc, line, col, true)
  end
  return line, col
end

---Don't call directly.
---@param doc core.doc
---@param line number
---@param col number
---@param continue_to_next_line boolean
local function translate_next_word_start_by_whitespace_impl(doc, line, col, continue_to_next_line)
  -- Correctly emulate the W command from Vim. It will
  -- stop on non-whitespace characters. Then skip to the next word.
  -- If it has to line wrap then it will skip to the first
  -- non-whitespace on that line.

  local last_col = #doc.lines[line]
  local initial_is_whitespace = is_whitespace(doc:get_char(line, col))
  local first_whitespace = true
  while col < last_col do
    col = col + 1
    local col_value = doc:get_char(line, col)

    if first_whitespace and is_whitespace(col_value) then
      initial_is_whitespace = true
      first_whitespace = false
    elseif initial_is_whitespace ~= is_whitespace(col_value) then
      return line, col
    end
  end

  if not continue_to_next_line then
    return line, last_col
  end

  -- On the next line, continue until we have non-whitespace.
  line = line + 1
  col = 0
  last_col = #doc.lines[line]
  while col < last_col do
    col = col + 1
    if not is_whitespace(doc:get_char(line, col)) then
      return line, col
    end
  end

  -- Just a default in case the next line was empty or contains only whitespace.
  return line, 0
end

---@type vimxl.motion
function vim_translate.next_word_start_by_whitespace(doc, line, col, _, numerical_argument)
  if numerical_argument == nil or numerical_argument < 1 then numerical_argument = 1 end
  for _ = 1, numerical_argument do
    line, col = translate_next_word_start_by_whitespace_impl(doc, line, col, false)
  end
  return line, col
end

---@type vimxl.motion
function vim_translate.next_word_start_by_whitespace_multiline(doc, line, col, _, numerical_argument)
  if numerical_argument == nil or numerical_argument < 1 then numerical_argument = 1 end
  for _ = 1, numerical_argument do
    line, col = translate_next_word_start_by_whitespace_impl(doc, line, col, true)
  end
  return line, col
end

---Don't call directly.
---@param doc core.doc
---@param line number
---@param col number
local function translate_prev_word_start_impl(doc, line, col)
  -- Correctly emulate the b command from Vim.
  -- Unlike the equivalent Lite-XL built-in translation,
  -- this translation will stop on non-words as well as line-start
  -- to better mimic Vim itself. 

  local start_col = col

  -- Don't get stuck...
  -- We allow it to go to 0 because then handle-wrap will know what to do.
  if col >= 1 then
    col = col - 1
  end
  local col_value = doc:get_char(line, col)

  while col >= 1 and is_whitespace(col_value) do
    col = col - 1
    col_value = doc:get_char(line, col)
  end

  -- Handle wrap to end of last line.
  if col == 0 and line > 1 then
    line = line - 1
    col = #doc.lines[line]
    start_col = col
    col_value = doc:get_char(line, col)
  end

  while col > 1 and is_whitespace(col_value) do
    col = col - 1
    col_value = doc:get_char(line, col)
  end

  local initial_is_non_word = is_non_word(col_value)

  while col >= 1 do
    if initial_is_non_word ~= is_non_word(col_value)
    or is_whitespace(col_value) then
      if col + 1 == start_col then
        return line, col
      else
        return line, col + 1
      end
    end

    col = col - 1
    col_value = doc:get_char(line, col)
  end

  -- We reached the start of the line without finding anything. Stop here.
  return line, 1
end

---@type vimxl.motion
function vim_translate.prev_word_start(doc, line, col, _, numerical_argument)
  if numerical_argument == nil or numerical_argument < 1 then numerical_argument = 1 end
  for _ = 1, numerical_argument do
    line, col = translate_prev_word_start_impl(doc, line, col)
  end
  return line, col
end

---Don't call directly.
---@param doc core.doc
---@param line number
---@param col number
local function translate_prev_word_start_by_whitespace_impl(doc, line, col)
  -- Correctly emulate the B command from Vim.
  -- Unlike the equivalent Lite-XL built-in translation,
  -- this translation will only stop on whitespace but also the line-start.



  -- Don't get stuck...
  if col >= 1 then
  col = col - 1
  end
  local col_value = doc:get_char(line, col)

  while col >= 1 and is_whitespace(col_value) do
    col = col - 1
    col_value = doc:get_char(line, col)
  end

  -- Handle wrap to end of last line.
  if col == 0 and line > 1 then
    line = line - 1
    col = #doc.lines[line] - 1
    col_value = doc:get_char(line, col)
  end

  while col >= 1 do
    if is_whitespace(col_value) then
      return line, col + 1
    end

    col = col - 1
    col_value = doc:get_char(line, col)
  end

  -- We reached the start of the line without finding anything. Stop here.
  return line, 1
end

---@type vimxl.motion
function vim_translate.prev_word_start_by_whitespace(doc, line, col, _, numerical_argument)
  if numerical_argument == nil or numerical_argument < 1 then numerical_argument = 1 end
  for _ = 1, numerical_argument do
    line, col = translate_prev_word_start_by_whitespace_impl(doc, line, col)
  end
  return line, col
end

---@type vimxl.motion
function vim_translate.end_of_line(_, line, _, _, extra)
  if extra == nil then extra = 1 end
  return line + extra - 1, math.huge
end

---@type vimxl.motion
function vim_translate.start_of_line(_, line)
  return line, 1
end

---@type vimxl.motion
function vim_translate.up(_, line, col, _, by)
  if by == nil then by = 1 end
  return line - by, col
end

---@type vimxl.motion
function vim_translate.down(_, line, col, _, by)
  if by == nil then by = 1 end
  return line + by, col
end

---@type vimxl.motion
function vim_translate.left(_, line, col, _, by)
  if by == nil then by = 1 end
  return line, col - by
end

---@type vimxl.motion
function vim_translate.right(_, line, col, _, by)
  if by == nil then by = 1 end
  return line, col + by
end

---@type vimxl.motion
function vim_translate.right_clamped(doc, line, col, _, by)
  if by == nil then by = 1 end
  return line, math.min(col + by, #doc.lines[line] - 1)
end

---@type vimxl.motion
function vim_translate.nth_col(_, line, _, _, to)
  if to == nil then to = 1 end
  return line, to
end

---@type vimxl.motion
function vim_translate.nth_line_printable(doc, line, _, _, to)
  ---Make sure that 0 is an acceptable argument, or else
  ---we will break:
  ---@see vim_translate.first_printable
  if to == nil then to = 1 end
  line = line + to
  local leading_whitespace = #doc.lines[line]:match(constants.LEADING_INDENTATION_REGEX)
  return line, 1 + leading_whitespace
end

---@type vimxl.motion
function vim_translate.first_printable(doc, line, col, view)
  return vim_translate.nth_line_printable(doc, line, col, view, 0)
end

---@type vimxl.motion
function vim_translate.nth_line_minus_one_printable(doc, line, col, view, to)
  if to == nil then to = 1 end
  return vim_translate.nth_line_printable(doc, line, col, view, to - 1)
end

---@type vimxl.motion
function vim_translate.entire_current_line_or_more(_, line, _, _ , extra)
  if extra == nil or extra < 1 then extra = 1 end
  return line, 0, line + extra, 0
end

---@type vimxl.motion
function vim_translate.end_of_doc_or_line_number(doc, _, col, _, dest)
  if dest == nil or dest == 0 then dest = #doc.lines end
  return dest, col
end

---@type vimxl.motion
function vim_translate.inner_word(doc, line, col)
  local l1, c1 = line, col
  local l2, c2 = line, col

  local col_value = doc:get_char(line, col)
  local initial_type = classify_type(col_value)

  while c1 > 1 do
    col = c1 - 1
    col_value = doc:get_char(line, col)
    local char_type = classify_type(col_value)
    if initial_type ~= char_type then
      break
    else
      c1 = col
    end
  end

  while c2 < #doc.lines[line] do
    c2 = c2 + 1
    col_value = doc:get_char(line, c2)
    local char_type = classify_type(col_value)
    if initial_type ~= char_type then
      break
    end
  end

  return l1, c1, l2, c2
end

vim_translate.previous_char = doc_translate.previous_char
vim_translate.next_char = doc_translate.next_char

return vim_translate
