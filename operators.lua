local core = require "core"
local constants = require "plugins.vimxl.constants"
local vim_translate = require "plugins.vimxl.translate"
local vim_motionmodes = require "plugins.vimxl.motionmodes"

---Contains functions useful for creating operators. A bit of a misnomer.
---But in some sense it contains "generic" operators.
local operators = {}

---This is how Vim behaves. Don't question it.
---@param a number | nil
---@param b number | nil
function operators.product_with_strange_default(a, b)
  if a == nil and b == nil then return nil end
  return (a or 1) * (b or 1)
end

---This function only exists so that indent and unindent in
---normal mode may share their implementations.
---@param start_state vimxl.vimstate
---@param numerical_argument_operator? number
---@param unindent boolean
function operators.generic_normal_indent(start_state, numerical_argument_operator, unindent)
  start_state:expect_motion(function (second_state, motion_mode, motion, numerical_argument_motion)
    local product_numerical_argument = operators.product_with_strange_default(numerical_argument_operator, numerical_argument_motion)
    second_state:begin_naive_repeatable_command(function (state)
      for _, l1, c1, l2, c2 in state:get_operator_selections(motion_mode, motion, product_numerical_argument) do
        l2 = l2 - 1
        state.view.doc:indent_text(unindent, l1, c1, l2, c2)
      end
    end)
  end)
end

---The purpose is to unselect the newline from the latter end
---of a selection. We only return the new lines because
---the users of this function are only interested in lines for now.
---Mainly used by:
---@see operators.generic_visual_indent
---@param l1 number
---@param c1 number
---@param l2 number
---@param c2 number
local function unselect_newline(l1, c1, l2, c2)
  if l1 == l2 and c1 == c2 then
    return l1, l2
  end
  if l1 > l2 or (l1 == l2 and c1 > c2) then
    l1, c1, l2, c2 = l2, c2, l1, c1
  end
  if l2 > 1 and c2 <= 1 then
    l2 = l2 - 1
  end
  return l1, l2
end

---This function only exists so that indent and unindent in
---visual mode may share their implementations.
---@param start_state vimxl.vimstate
---@param numerical_argument? number
---@param unindent boolean
function operators.generic_visual_indent(start_state, numerical_argument, unindent)
  -- TODO: Perhaps handle block-mode here as well?

  local lines = {}
  local first_line1, first_line2 = unselect_newline(start_state.view.doc:get_selection())
  local first_line = math.min(first_line1, first_line2)

  for _, l1, c1, l2, c2 in start_state.view.doc:get_selections() do
    l1, l2 = unselect_newline(l1, c1, l2, c2)

    for line = math.min(l1, l2), math.max(l1, l2) do
      lines[line - first_line] = true
    end
  end
  start_state:begin_naive_repeatable_command(function (state)
    local start_line1, start_line2 = unselect_newline(start_state.view.doc:get_selection())
    local start_line = math.min(start_line1, start_line2)
    local lowest_line = math.maxinteger
    -- We use pairs instead of ipairs to support negative (and zero) indices.
    for offset in pairs(lines) do
      local line = start_line + offset
      lowest_line = math.min(lowest_line, line)
      state.view.doc:indent_text(unindent, line, 0, line, 1)
    end
    -- Mimic Vim behaviour.
    if lowest_line ~= math.maxinteger then
      state.view.doc:move_to(vim_translate.first_printable, state.view)
      local indentation = string.ulen(state.view.doc.lines[lowest_line]:match(constants.LEADING_INDENTATION_REGEX))
      state.view.doc:set_selection(lowest_line, indentation + 1)
    end
  end, numerical_argument)
  start_state:set_mode("n")
end

---Don't delete anything
operators.DELETE_STYLE_DISABLED = 0

---Delete everything that got selected
operators.DELETE_STYLE_ALL = 1

---Keep one line (for cc and similar commands)
operators.DELETE_STYLE_KEEP_LINE = 2

---When text is deleted we must move the cursor!
---@see operators.generic_cut_or_copy
---@param move_to_line? number
---@param move_to_col? number
---@param l1 number
---@param c1 number
---@param l2? number | unknown
---@param c2? number | unknown
---@param is_linewise boolean
local function adjust_cursor_during_deletion(move_to_line, move_to_col, l1, c1, l2, c2, is_linewise)
  if move_to_line == nil then
    return move_to_line, move_to_col
  end

  if move_to_line < l1 then
    return move_to_line, move_to_col
  end

  local line_removal = l2 - l1
  local col_removal = c2 - c1

  local new_line, new_col = move_to_line, move_to_col
  if move_to_line > l1 or (move_to_line == l1 and move_to_col > c1) then
    if move_to_line > l2 then
      new_line = new_line - line_removal
    else
      new_line = l1
      if not is_linewise then
        new_col = (move_to_line == l2 and move_to_col > 2) and new_col - col_removal or c1
      end
    end
  end

  return new_line, new_col
end

local function pick_top_left(current_line, current_col, line, col)
  if line < current_line then
    return line, col
  elseif line == current_line and col < current_col then
    return line, col
  else
    return current_line, current_col
  end
end

operators.PASTE_DISABLED = 0

operators.PASTE_AFTER_AND_MOVE = 1

operators.PASTE_BEFORE_AND_MOVE = 2

operators.CURSOR_SINGLE_LINE = 0

operators.CURSOR_MULTI_LINE = 1

---@param state vimxl.vimstate
---@param delete_style 0|1|2
---@param should_set_clipboard boolean
---@param paste_style 0|1|2
---@param cursor_style 0|1
---@param motion_mode vimxl.motion_mode
---@param motion? vimxl.motion
---@param numerical_argument? number
function operators.generic_replace(state, delete_style, should_set_clipboard, paste_style, cursor_style, motion_mode, motion, numerical_argument)
  local separator = ""

  -- TODO: This isn't the prettiest way of deciding this.
  if state.mode == "v-block" then
    separator = "\n"
  end

  ---@type core.doc
  local doc = state.view.doc

  local full_text = ""

  local old_cursor_clipboard = core.cursor_clipboard
  local old_cursor_clipboard_whole_line = core.cursor_clipboard_whole_line

  if paste_style ~= operators.PASTE_DISABLED then
    local old_clipboard = system.get_clipboard()

    -- Make sure we are using the latest clipboard data.
    if old_cursor_clipboard["full"] ~= old_clipboard then
      old_cursor_clipboard = {}
      old_cursor_clipboard[1] = old_clipboard
      old_cursor_clipboard["full"] = old_clipboard
      old_cursor_clipboard_whole_line = {}
      old_cursor_clipboard_whole_line[1] = old_clipboard:match("\n$") ~= nil
    end
  end

  local new_cursor_clipboard = {}
  local new_cursor_clipboard_whole_line = {}

  -- How many selections that should be deleted.
  local total_fused = 0

  local move_to_line, move_to_col, line_direction, line_start = state:get_visual_start()

  local bottom_line = 0
  local top_line = math.maxinteger
  local top_col = 0

  for idx, line1, col1, line2, col2, fused in state:get_operator_selections(motion_mode, motion, numerical_argument) do
    total_fused = total_fused + fused

    local keep_indent = false
    if delete_style == operators.DELETE_STYLE_ALL and line2 > #state.view.doc.lines then
      -- Handle the deletion of the last lines by removing an extra newline.
      line1 = line1 - 1
      col1 = #state.view.doc.lines[line1]
      keep_indent = true
    elseif delete_style == operators.DELETE_STYLE_KEEP_LINE and line1 ~= line2 and col2 <= 1 and col1 <= 1 then
      -- This was a linewise remove. But we don't want to
      -- remove the last newline because of our style.
      line2 = line2 - 1
      col2 = math.huge
      keep_indent = true
    end

    top_line, top_col = pick_top_left(top_line, top_col, line1, col1)
    top_line, top_col = pick_top_left(top_line, top_col, line2, col2)
    bottom_line = math.max(bottom_line, math.max(line1, line2))

    if line1 ~= line2 or col1 ~= col2 then
      local text = doc:get_text(line1, col1, line2, col2)

      local at_end_of_line = line2 > #doc.lines or (col2 >= #doc.lines[line2])
      if at_end_of_line and motion_mode == vim_motionmodes.MOTION_MODE_LINEWISE and not text:match("\n$") then
        -- Make sure that we have a line-ending always if we are in linewise mode and are outside the bounds.
        -- In other words, at the end of the file.
        text = text .. "\n"
      end

      full_text = full_text == "" and text or (text .. separator .. full_text)
      new_cursor_clipboard_whole_line[idx] = text:match("\n$") ~= nil

      local leading_whitespace = 0
      if keep_indent then
          -- It is also implied that we keep the indentation. We keep it by skipping over it.
          leading_whitespace = #doc.lines[line1]:match(constants.LEADING_INDENTATION_REGEX)
      end

      if delete_style ~= operators.DELETE_STYLE_DISABLED then
        doc:remove(line1, col1, line2, col2)
        move_to_line, move_to_col = adjust_cursor_during_deletion(move_to_line, move_to_col, line1, col1, line2, col2, line_direction ~= 0)
      end

      if keep_indent then
        move_to_line = line1
        move_to_col = leading_whitespace + 1
      end
      new_cursor_clipboard[idx] = text
    else
      new_cursor_clipboard[idx] = ""
    end
  end

  new_cursor_clipboard["full"] = full_text

  -- TODO: This isn't the prettiest way of deciding this.
  if state.mode == "v-block" then
    new_cursor_clipboard["is_blockwise"] = true
  end

  if should_set_clipboard then
    core.cursor_clipboard = new_cursor_clipboard
    core.cursor_clipboard_whole_line = new_cursor_clipboard_whole_line
    system.set_clipboard(full_text)
  end

  if line_direction > 0 and delete_style == operators.DELETE_STYLE_DISABLED then
    move_to_col = 0
    move_to_line = line_start
  end

  if paste_style ~= operators.PASTE_DISABLED then
    local did_linewise = false
    local did_charwise = false
    local is_blockwise = old_cursor_clipboard["is_blockwise"]
    local indentation = -1
    local total_pastes = 0

    for k, v in ipairs(old_cursor_clipboard) do
      total_pastes = total_pastes + 1
      v = v:gsub("\r", "")
      local line = top_line + k - 1
      if old_cursor_clipboard_whole_line[k] and not did_charwise then
        indentation = string.ulen(v:match(constants.LEADING_INDENTATION_REGEX))
        did_linewise = true

        local col = top_col
        if paste_style == operators.PASTE_BEFORE_AND_MOVE then
          col = 0
        elseif paste_style == operators.PASTE_AFTER_AND_MOVE then
          col = math.maxinteger
          v = "\n" .. v:sub(1, -2)
        end
        doc:insert(line, col, v)
      elseif is_blockwise then
        local col = top_col
        if paste_style == operators.PASTE_AFTER_AND_MOVE then
          col = col + 1
        end

        doc:insert(line, col, v)
      else
        local col = top_col
        if not did_charwise and paste_style == operators.PASTE_AFTER_AND_MOVE then
          col = col + 1
        end
        did_charwise = true

        doc:insert(top_line, col, v)
        top_line, top_col = doc:position_offset(top_line, col, #v - 1)

        -- TODO: Check that paste works with multiple non-blockwise old_cursor_clipboard entries (regarding correct paste locations)
      end
    end

    if did_charwise then
      move_to_line, move_to_col = top_line, top_col
    elseif is_blockwise then
      if paste_style == operators.PASTE_AFTER_AND_MOVE then
        move_to_line = top_line
        move_to_col = top_col + 1
      elseif paste_style == operators.PASTE_BEFORE_AND_MOVE then
        move_to_line = top_line
        move_to_col = top_col
      end
    elseif did_linewise then
      if paste_style == operators.PASTE_AFTER_AND_MOVE then
        move_to_line = top_line + 1
        move_to_col = indentation + 1
      elseif paste_style == operators.PASTE_BEFORE_AND_MOVE then
        move_to_line = top_line
        move_to_col = indentation + 1
      end
    end
  end

  if move_to_line and move_to_line > #doc.lines then
    move_to_line = #doc.lines
  end

  if move_to_line and move_to_col then
    -- TODO: Not sure if rm of set_selection is API stable.
    doc:set_selections(1, move_to_line, move_to_col, move_to_line, move_to_col, false, total_fused * 4)
    if cursor_style == operators.CURSOR_MULTI_LINE then
      local total_lines = bottom_line - top_line
      for offset = 1, total_lines do
        local line = move_to_line + offset
        if #doc.lines[line] >= move_to_col then
          -- Vim doesn't affect lines that are too short.
          doc:add_selection(line, move_to_col, line, move_to_col)
        end
      end
    end
  end

  return full_text
end

return operators
