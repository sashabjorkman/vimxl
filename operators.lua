local core = require "core"
local constants = require "plugins.vimxl.constants"
local vim_translate = require "plugins.vimxl.translate"

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
  start_state:expect_motion(function (second_state, motion, numerical_argument_motion)
    local product_numerical_argument = operators.product_with_strange_default(numerical_argument_operator, numerical_argument_motion)
    second_state:begin_naive_repeatable_command(function (state)
      for _, line, col in state.view.doc:get_selections(true) do
        local l1, c1, l2, c2 = motion(state.view.doc, line, col, state.view, product_numerical_argument)
        l2 = l2 - 1
        state.view.doc:indent_text(unindent, l1, c1, l2, c2)
      end
    end)
  end)
end

---The purpose is to unselect the newline from both ends
---of a selection. We only return the new lines because
---the users of this function are only interested in lines for now.
---Mainly used by:
---@see operators.generic_visual_indent
---@param l1 number
---@param c1 number
---@param l2 number
---@param c2 number
local function unselect_newline(l1, c1, l2, c2)
  if l1 > 1 and c1 <= 1 then
    l1 = l1 - 1
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
      --table.insert(lines, line - first_line)
      lines[line - first_line] = true
    end
  end
  start_state:begin_naive_repeatable_command(function (state)
    local start_line1, start_line2 = unselect_newline(start_state.view.doc:get_selection())
    local start_line = math.min(start_line1, start_line2)
    for line in ipairs(lines) do
      state.view.doc:indent_text(unindent, start_line + line, 0, start_line + line, 1)
    end
    -- Mimic Vim behaviour.
    if #lines > 0 then
      state.view.doc:move_to(vim_translate.first_printable, state.view)
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

---@param state vimxl.vimstate
---@param delete_style 0|1|2
---@param motion? vimxl.motion
---@param numerical_argument? number
function operators.generic_cut_or_copy(state, delete_style, motion, numerical_argument)
  -- TODO: For block mode, we can use core.cursor_clipboard_whole_line to paste in the correct manner.

  local separator = ""

  -- TODO: This isn't the prettiest way of deciding this.
  if state.mode == "v-block" then
    separator = "\n"
  end

  ---@type core.doc
  local doc = state.view.doc

  local full_text = ""
  local text = ""
  core.cursor_clipboard = {}
  core.cursor_clipboard_whole_line = {}

  -- How many selections that should be deleted.
  local total_fused = 0

  local move_to_line, move_to_col, line_direction, line_start = state:get_visual_start()
  --core.error("start %d %d", move_to_line, move_to_col)

  for idx, line1, col1, line2, col2, fused in state:get_operator_selections(motion, numerical_argument) do
    total_fused = total_fused + fused

    local keep_indent = false
    if delete_style == operators.DELETE_STYLE_ALL and line2 >= #state.view.doc.lines then
      -- Handle the deletion of the last lines by removing an extra newline.
      line1 = line1 - 1
      col1 = #state.view.doc.lines[line1]
    elseif delete_style == operators.DELETE_STYLE_KEEP_LINE and line1 ~= line2 and col2 <= 1 and col1 <= 1 then
      -- This was a linewise remove. But we don't want to
      -- remove the last newline because of our style.
      line2 = line2 - 1
      col2 = math.huge
      keep_indent = true
    end

    if line1 ~= line2 or col1 ~= col2 then
      text = doc:get_text(line1, col1, line2, col2)
      full_text = full_text == "" and text or (text .. separator .. full_text)
      core.cursor_clipboard_whole_line[idx] = separator == "\n"

      if keep_indent then
          -- It is also implied that we keep the indentation. We keep it by skipping over it.
          local leading_whitespace = #doc.lines[line1]:match(constants.LEADING_INDENTATION_REGEX)
          col1 = leading_whitespace + 1
      end

      if delete_style ~= operators.DELETE_STYLE_DISABLED then
        doc:remove(line1, col1, line2, col2)
        move_to_line, move_to_col = adjust_cursor_during_deletion(move_to_line, move_to_col, line1, col1, line2, col2, line_direction ~= 0)
      end
    end
    core.cursor_clipboard[idx] = text
  end
  core.cursor_clipboard["full"] = full_text
  system.set_clipboard(full_text)

  if line_direction > 0 and delete_style == operators.DELETE_STYLE_DISABLED then
    move_to_col = 0
    move_to_line = line_start
  end

  if move_to_line and move_to_col then
    -- TODO: Not sure if rm of set_selection is API stable.
    doc:set_selections(1, move_to_line, move_to_col, move_to_line, move_to_col, false, total_fused * 4)
  end


  -- TODO: This isn't the prettiest way of deciding this.
  --if state.mode == "v-block" then
  --  state.view.doc:set_selection()
  --end

  return full_text
end

return operators
