-- Vim and LiteXL implement some basic translations a bit differnetly.
-- This file contains functions that implement the correct Vim behaviour. 

local constants = require "plugins.vimxl.constants"

-- Only used for inner_word implementation. And for prev_char next_char.
-- TODO: Maybe reimplement and drop the dependency?
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

-- Collection of translations implementing Vim-specific behaviour.
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
  while col < last_col do
    col = col + 1
    local col_value = doc:get_char(line, col)

    if is_whitespace(col_value) then
      -- From here on: stop at first word.
      initial_is_non_word = true
    elseif initial_is_non_word ~= is_non_word(col_value) then
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

  -- Handle wrap to end of last line.
  if col == 1 and line > 1 then
    line = line - 1
    col = #doc.lines[line]
  end

  -- Don't get stuck...
  col = col - 1
  local col_value = doc:get_char(line, col)

  while col >= 1 and is_whitespace(col_value) do
    col = col - 1
    col_value = doc:get_char(line, col)
  end

  local initial_is_non_word = is_non_word(col_value)
  while col >= 1 do
    if initial_is_non_word ~= is_non_word(col_value) then
      return line, col + 1
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

  -- Handle wrap to end of last line.
  if col == 1 and line > 1 then
    line = line - 1
    col = #doc.lines[line]
  end

  -- Don't get stuck...
  col = col - 1
  local col_value = doc:get_char(line, col)

  while col >= 1 and is_whitespace(col_value) do
    col = col - 1
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
function vim_translate.nth_col(_, line, _, _, to)
  if to == nil then to = 1 end
  return line, to
end

---@type vimxl.motion
function vim_translate.first_printable(doc, line)
  local leading_whitespace = #doc.lines[line]:match(constants.LEADING_INDENTATION_REGEX)
  return line, 1 + leading_whitespace
end

---@type vimxl.motion
function vim_translate.cursor_to_nth_line_printable(doc, line, _, _, to)
  if to == nil then to = 1 end
  line = line + to - 1
  local leading_whitespace = #doc.lines[line]:match(constants.LEADING_INDENTATION_REGEX)
  return line, 0, line, 1 + leading_whitespace
end

---@type vimxl.motion
function vim_translate.entire_current_line_or_more(_, line, _, _ , extra)
  if extra == nil or extra < 1 then extra = 1 end
  return line, 0, line + extra, 0
end

---@type vimxl.motion
function vim_translate.current_line_to_doc_start_or_line(_, line, _, _, numerical_argument)
  if numerical_argument ~= nil and numerical_argument > 0 then
    if numerical_argument >= line then
      return line, 0, numerical_argument + 1, 0
    else
      return numerical_argument, 0, line + 1, 0
    end
  else
    return 0, 0, line + 1, 0
  end
end

---@type vimxl.motion
function vim_translate.goto_line_by_number(doc, _, col, _, dest)
  if dest == nil or dest == 0 then dest = #doc.lines end
  return dest, col
end

---@type vimxl.motion
function vim_translate.select_entire_line_by_number(doc, line, _, _, dest)
  if dest == nil or dest == 0 then dest = #doc.lines end
  if dest >= line then
    return line, 0, dest + 1, 0
  else
    return dest, 0, line + 1, 0
  end
end

---@type vimxl.motion
function vim_translate.inner_word(doc, line, col)
  local l1, c1 = translate_prev_word_start_impl(doc, line, col)
  local l2, c2 = doc_translate.end_of_word(doc, line, col)
  return l1, c1, l2, c2
end

vim_translate.previous_char = doc_translate.previous_char
vim_translate.next_char = doc_translate.next_char

return vim_translate
