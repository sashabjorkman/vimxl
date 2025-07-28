local core = require "core"
local style = require "core.style"
local command = require "core.command"
local Object = require "core.object"
local config = require "core.config"
local ime = require "core.ime"

local vim_functions = require "plugins.vimxl.functions"
local vim_motions = require "plugins.vimxl.motions"
local vim_keymap = require "plugins.vimxl.keymap"
local vim_linewise = require "plugins.vimxl.linewise"
local constants = require "plugins.vimxl.constants"

---This object is inserted into a DocView to indicate that Vim-mode has been
---enabled for that DocView. This object is self-contained when it comes to
---all data it needs to properly implement Vim-mode.
---@class vimxl.vimstate : core.object
---@field super core.object
local VimState = Object:extend()

---All possible modes supported by VimXL by default.
---@alias vimxl.mode "i"|"v"|"n"|"v-block"|"v-line"

---Stuff relating to command_history:

---Stored inside of repeatable_commands
---We want to differentiate performs that take a number argument
---from those that don't so that the "dot" command can safely modify
---the numerical value.
---However, the nil value is also treated as a valid value for the
---numerical argument, hence why it is optional.
---@see vimxl.vimstate.begin_command_with_numerical_argument
---@alias vimxl.perform_with_optional_number fun(state: vimxl.vimstate, n: number | nil)
---
---Stored inside of repeatable_commands.
---@see vimxl.perform_with_number For explanation on its sibling type.
---@see vimxl.vimstate.begin_naive_repeatable_command
---@alias vimxl.perform_no_number fun(state: vimxl.vimstate)
---
---Base type for everything that goes into command_history.
---@class vimxl.repeatable_command
---@field type "dummy"
---
---@class vimxl.repeatable_text_input : vimxl.repeatable_command
---@field type "text_input"
---@field text string
---
---@class vimxl.repeatable_remove_text : vimxl.repeatable_command
---@field type "remove_text"
---@field amount number
---
---@class vimxl.repeatable_command_supporting_number : vimxl.repeatable_command
---@field type "command_supporting_number"
---@field perform vimxl.perform_with_optional_number
---@field number number | nil
---
---@class vimxl.repeatable_command_no_number : vimxl.repeatable_command
---@field type "command"
---@field perform vimxl.perform_no_number
---
---@class vimxl.repeatable_select_to : vimxl.repeatable_command
---@field type "select_to"
---@field perform vimxl.perform_no_number
---
---@class vimxl.repeatable_move_to : vimxl.repeatable_command
---@field type "move_to"
---@field translate vimxl.motion
---
---@class vimxl.repeatable_everything : vimxl.repeatable_command
---@field type "repeat_everything"
---@field number number
---
--- A collection of all known types that go into command_history.
---@alias vimxl.repeatable_generic vimxl.repeatable_text_input | vimxl.repeatable_remove_text | vimxl.repeatable_command_supporting_number | vimxl.repeatable_command_no_number | vimxl.repeatable_move_to | vimxl.repeatable_select_to | vimxl.repeatable_everything | vimxl.repeatable_command

function VimState:__tostring() return "VimState" end

---@param view core.docview
function VimState:new(view)
  VimState.super.new(self)

  ---The view that this instance of Vim-emulation is attached to.
  self.view = view

  ---Which Vim mode we are emulating, i.e normal-mode, insert-mode, etc...
  ---@type vimxl.mode
  self.mode = "n"

  ---Since some keybinds are only available when preceeded by others we
  ---must track some kind of state to know which keys are available.
  ---Simply looking a self.mode is not enough.
  ---@type vimxl.keybind_map
  self.keymap = vim_keymap.normal

  ---A portion of edit commands that can later be moved to repeatable_commands
  ---in order to repeat them.
  ---@type vimxl.repeatable_generic[]
  self.command_history = {}

  ---A complete set of repeatable commands. To not append, only set.
  ---@type vimxl.repeatable_generic[]
  self.repeatable_commands = {}

  -- Should a repeat be performed?
  self.repeat_requested = false

  -- Tracked such that yy, dd & cc represent "entire line" motions.
  self.operator_name = ""

  ---What function to call once we have obtained a motion.
  ---Note that a value of nil means that we are not expecting a motion.
  --- @type vimxl.motion_cb | nil
  self.operator_got_motion_cb = nil

  ---Accumulated thru 0-9 keys.
  ---@type number | nil
  self.numerical_argument = nil

  ---Should we record basic function calls like Doc:insert to history?
  ---This is mainly used for a less intrusive way of tracking autocomplete.
  self.track_primitives = false
end
---This callback has a chance to be triggered after a valid motion
---is detected. However it can also never be called if the user fails
---to provide a valid motion on the first try. 
---@alias vimxl.motion_cb fun(state: vimxl.vimstate, motion: vimxl.motion, numerical_argument: number)

---Inform Vim that we a command has kindly asked for a motion.
---@param cb vimxl.motion_cb
function VimState:expect_motion(cb)
  self.operator_got_motion_cb = cb
  self.keymap = vim_keymap.motions
end

local function is_selection_going_forward(l1, c1, l2, c2)
  return l1 > l2 or l1 == l2 and c1 > c2
end

---Implements the Vim visual mode of navigation
---where the cursor is always on a character and not just
---in between two.
---@param doc core.doc
---@param start_line number
---@param start_col number
---@param view core.docview
---@param numerical_argument? number
---@param translate_fn vimxl.motion
---@param end_line number
---@param end_col number
local function vim_style_visual_select_to_impl(doc, start_line, start_col, view, numerical_argument, translate_fn, end_line, end_col)
  -- Detect if a character is not currently selected and if so correct that.
  if start_line == end_line and start_col == end_col then
    start_col = start_col + 1
  end

  local was_neutral = start_line == end_line and start_col == end_col + 1
  local was_going_forward = is_selection_going_forward(start_line, start_col, end_line, end_col)

  -- Steal a character so that we go from having the cursor be
  -- on a character to having it be between characters.
  if was_going_forward then
    start_col = start_col - 1
  end

  local l1, c1, l2, c2 = translate_fn(doc, start_line, start_col, view, numerical_argument)

  local got_text_object = false

  -- Got text object. Extend current extension.
  if l2 ~= nil and c2 ~= nil then
    -- Sort them. Such that the default selection is "going forward".
    if not is_selection_going_forward(l1, c1, l2, c2) then
      l1, c1, l2, c2 = l2, c2, l1, c1
    end

    if was_neutral then
      got_text_object = true
    elseif was_going_forward then
      -- Is l2 & c2 further away from cursor? If so use that.
      if is_selection_going_forward(l2, c2, l1, c1) then
        l1 = l2
        c1 = c2
        -- l2 and c2 is later on.
      end
    else
      -- Is l2 & c2 further away from cursor? If so use that.
      if is_selection_going_forward(l1, c1, l2, c2) then
        l1 = l2
        c1 = c2
        -- l2 and c2 is later on.
      end
    end
  end

  if not got_text_object then
    -- Extend the selection because we were doing a simple movement.
    l2 = end_line
    c2 = end_col
  end

  local is_selecting = l1 ~= l2 or c1 ~= c2
  local is_going_forward = is_selection_going_forward(l1, c1, l2, c2)

  if is_selecting and was_going_forward and not is_going_forward then
    c2 = c2 + 1
  elseif is_selecting and not was_going_forward and is_going_forward then
    c2 = c2 - 1
  elseif not is_selecting or is_going_forward and not got_text_object then
    -- Give back the character we stole earlier.
    c1 = c1 + 1
  end

  -- If we are selecting only one character, then make it a normal "neutral" selection
  -- which is to say that c1 should be greater than c2, i.e selection goes forward.
  if l1 == l2 and c1 + 1 == c2 then
    c1, c2 = c2 or c1, c1 or c2
  end

  return l1, c1, l2, c2
end

---Implements the Vim visual block mode of navigation
---where the cursor is always on a character and not just
---in between two.
---@param l1 number
---@param c1 number
---@param l2 number
---@param c2 number
---@param was_going_forward boolean
local function vim_style_visual_block_select_to_impl(l1, c1, l2, c2, was_going_forward)
  local is_selecting = c1 ~= c2
  local is_going_forward = c1 > c2

  if is_selecting and was_going_forward and not is_going_forward then
    c2 = c2 + 1
  elseif is_selecting and not was_going_forward and is_going_forward then
    c2 = c2 - 1
  elseif not is_selecting or is_going_forward then
    -- Give back the character we stole earlier.
    c1 = c1 + 1
  end

  -- If we are selecting only one character, then make it a normal "neutral" selection
  -- which is to say that c1 should be greater than c2, i.e selection goes forward.
  if c1 + 1 == c2 then
    c1, c2 = c2 or c1, c1 or c2
  end

  return l1, c1, l2, c2
end

---@param l1 number
---@param c1 number
---@param l2 number
---@param c2 number
function VimState:create_block_selection(l1, c1, l2, c2)

  local new_selection = {}

  local increment = l1 > l2 and 1 or -1

  local count = 1
  -- Not the most elegant way of doing this. But sadly add_selection
  -- keeps the selections "sorted"... Which in most cases is probably a good thing,
  -- but in our case we use it to know which is the head and tail.
  -- TODO: This probably should be redone such that we track that elsewhere.
  for line = l2, l1, increment do
    new_selection[count] = line
    count = count + 1
    new_selection[count] = c1
    count = count + 1
    new_selection[count] = line
    count = count + 1
    new_selection[count] = c2
    count = count + 1
  end
  self.view.doc.selections = new_selection
  self.view.doc.last_selection = (count - 1) / 4
end

---Implements linewise visual select for us.
---@param doc core.doc
---@param cursor_line number
---@param cursor_col number
---@param start_line number
---@param end_line number
---@param was_going_forward boolean
local function vim_style_visual_line_select_impl(doc, cursor_line, cursor_col, start_line, end_line, was_going_forward)
  local is_going_forward = cursor_line >= end_line

  if was_going_forward and not is_going_forward then
    -- We switched sides.
    end_line = start_line
    start_line = cursor_line
  elseif not was_going_forward and is_going_forward then
    -- We also switched sides here.
    start_line = end_line
    end_line = cursor_line
  elseif is_going_forward then
    end_line = cursor_line
  else
    start_line = cursor_line
  end

  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  doc.selections = {}
  doc:add_selection(cursor_line, cursor_col, end_line + 1, 0)
  doc:add_selection(cursor_line, cursor_col, start_line, 0)
end

---Make a movement/selection within the current document, but also
---record to history if necessary so that the movement may be repeated.
---@param translate_fn vimxl.motion
---@param numerical_argument? number 
function VimState:move_or_select(translate_fn, numerical_argument)
  if self.mode == "v" then
    ---@param state vimxl.vimstate
    local function vim_style_visual_select_to(state)
        for idx, start_line, start_col, end_line, end_col in state.view.doc:get_selections() do
          local l1, c1, l2, c2 = vim_style_visual_select_to_impl(state.view.doc, start_line, start_col, state.view, numerical_argument, translate_fn, end_line, end_col)
          state.view.doc:set_selections(idx, l1, c1, l2, c2)
        end
    end

    vim_style_visual_select_to(self)

    table.insert(self.command_history, {
      ["type"] = "select_to",
      ["perform"] = vim_style_visual_select_to,
    })
  elseif self.mode == "v-block" then
    ---@param state vimxl.vimstate
    local function vim_style_visual_block_select_to(state)
      local start_line, start_col = state.view.doc:get_selection()
      local _, _, end_line, end_col = state.view.doc:get_selection_idx(1)

      -- Detect if a character is not currently selected and if so correct that.
      if start_col == end_col then
        start_col = start_col + 1
      end

      local was_going_forward = start_col > end_col

      -- Steal a character so that we go from having the cursor be
      -- on a character to having it be between characters.
      if was_going_forward then
        start_col = start_col - 1
      end

      local l1, c1, l2, c2 = translate_fn(state.view.doc, start_line, start_col, state.view, numerical_argument)

      if state.mode == "v-block" and l2 ~= nil and c2 ~= nil then
        -- If we get a text object, just select that text object
        -- and enter ordinary visual mode. As is done in Vim.
        -- TODO: This doesn't actually seem entirely correct, some text objects like inner word don't do this, while "i(" does.
        -- TODO: Do :help text-objects, we can see which text-objects are supposed to force linewise, or force charwise there.
        state:set_mode("v")
        if c1 == c2 then
          c1 = c1 + 1
        end
        if is_selection_going_forward(l2, c2, l1, c1) then
          l1, c1, l2, c2 = l2, c2, l1, c1
        end
        state.view.doc.set_selection(l1, c1, l2, c2)
        return
      end

      l1, c1, l2, c2 = vim_style_visual_block_select_to_impl(l1, c1, end_line, end_col, was_going_forward)
      state:create_block_selection(l1, c1, l2, c2)
    end

    vim_style_visual_block_select_to(self)

    table.insert(self.command_history, {
      ["type"] = "select_to",
      ["perform"] = vim_style_visual_block_select_to,
    })
  elseif self.mode == "v-line" then
    ---@param state vimxl.vimstate
    local function vim_style_visual_block_select_to(state)
      -- We try to get the last added and something else if possible.
      local not_last_selection = state.view.doc.last_selection > 1 and 1 or (#state.view.doc.selections / 4)
      local _, _, start_line, start_col = state.view.doc:get_selection_idx(not_last_selection)
      local cursor_line, cursor_col, end_line = state.view.doc:get_selection_idx(state.view.doc.last_selection)

      -- In my opinion it should be end_line we are decreasing.
      -- But that doesn't work for some reason.
      -- Logging revelas that start_line and end_line have their names swapped.
      -- But was_going_forward appears to be working correctly so
      -- I really don't know what is happening. Perhaps was_going_forward is wrongly named as well?
      -- TODO: Investigate
      if start_col <= 1 and start_line > 1 then
        -- We are always selecting the newline as well. So undo that for our movement first.
        start_line = start_line - 1
      end

      -- If cursor was at the end of our selection then we were moving forward.
      local was_going_forward = cursor_line == end_line

      local l1, c1, l2, c2 = translate_fn(state.view.doc, cursor_line, cursor_col, state.view, numerical_argument)

      if state.mode == "v-line" and l2 ~= nil and c2 ~= nil then
        -- If we get a text object, just select that text object
        -- and enter ordinary visual mode. As is done in Vim.
        -- TOOD: This doesn't actually seem entirely correct, some text objects like inner word don't do this, while "i(" does.
        state:set_mode("v")
        if c1 == c2 then
          c1 = c1 + 1
        end
        if is_selection_going_forward(l2, c2, l1, c1) then
          l1, c1, l2, c2 = l2, c2, l1, c1
        end
        state.view.doc:set_selection(l1, c1, l2, c2)
        return
      end

      vim_style_visual_line_select_impl(state.view.doc, l1, c1, start_line, end_line, was_going_forward)
    end

    vim_style_visual_block_select_to(self)

    table.insert(self.command_history, {
      ["type"] = "select_to",
      ["perform"] = vim_style_visual_block_select_to,
    })
  elseif self.mode == "i" then
    self.view.doc:move_to(translate_fn, self.view, numerical_argument)
    table.insert(self.command_history, {
      ["type"] = "move_to",
      ["translate"] = function (doc, line, col, view)
        return translate_fn(doc, line, col, view, numerical_argument)
      end,
    })
  else
    self.view.doc:move_to(translate_fn, self.view, numerical_argument)
  end
end

function VimState:on_text_input(text)
  if self.mode == "i" then
    table.insert(self.command_history, {
      ["type"] = "text_input",
      ["text"] = text
    })
    self.view.doc:text_input(text)
    return
  end

  -- This variable has no business being enabled if outside of i-mode.
  self.track_primitives = false

  if self.numerical_argument == nil and text == "0" then
    text = constants.LEADING_ZERO
  end

  -- Operator got motion cb being set is the same as expecting a motion.
  if self.operator_got_motion_cb ~= nil and text == self.operator_name then
    text = constants.MOTION_LINE_REPEAT
  end

  ---@type vimxl.keybind_value
  local lookup_name = self.keymap[text]
  local lookup_type = type(lookup_name)

  local as_motion = nil
  local as_function = nil
  local as_keymap = nil
  local as_litexl_command = nil
  local as_number = nil

  -- Resolve the a function from its name.
  if lookup_type == "string" and vim_motions[lookup_name] then
    as_motion = vim_motions[lookup_name]
  elseif lookup_type == "string" and vim_functions[lookup_name] then
    as_function = vim_functions[lookup_name]
  elseif lookup_type == "string" and command.map[lookup_name] then
    as_litexl_command = lookup_name
  elseif lookup_type == "table" then
    as_keymap = lookup_name
  elseif type(text) == "string" and string.ubyte(text, 1) <= 57 and string.ubyte(text, 1) >= 48 then
    as_number = string.ubyte(text, 1) - 48
  elseif lookup_type ~= "nil" then
    -- We handle nil elsewhere
    core.error("Unsupported type found in keymap for: %s", text)
  end

  local reset_numerical_argument = true
  local reset_keymap = true

  if as_keymap ~= nil then
    self.keymap = as_keymap
    reset_numerical_argument = false
    reset_keymap = false
  elseif as_litexl_command ~= nil then
    command.perform(as_litexl_command, self)
  elseif as_motion ~= nil then
    -- Unset the cb to flag that we no longer expect
    -- a motion. We do this before calling in case we
    -- ask for two motions or something strange like that.
    local motion_cb = self.operator_got_motion_cb
    self.operator_got_motion_cb = nil

    local is_linewise = vim_linewise[lookup_name]

    -- Either we move or we call the cb. Anything else would be silly...
    if motion_cb then
      motion_cb(self, function (doc, line, col, view, numerical_argument)
        -- We create a new lambda scope each time we use a motion
        -- together with an operator. This might seem inefficient but
        -- it is actually to avoid having to create and store many different
        -- variations of similar translations.

        local l1, c1, l2, c2 = as_motion(doc, line, col, view, numerical_argument)

        -- If the function wasn't a text-object then we make sure the selection
        -- goes from the cursor to the new location.
        if l2 == nil then l2 = line end
        if c2 == nil then c2 = col end

        -- Sanitize them for the is_linewise step.
        -- Otherwise we end up incrementing the wrong thing.
        if l1 > l2 or l1 == l2 and c1 > c2 then
          l1, c1, l2, c2 = l2, c2, l1, c1
        end

        if is_linewise then
          c1 = 0
          c2 = 0
          l2 = l2 + 1
        end

        return l1, c1, l2, c2
      end, self.numerical_argument)
    else
      -- Because the key we used for our lookup was
      -- found in the vim_motions table
      -- we try to use it as such and do a move or select
      -- depending on the mode.
      self:move_or_select(as_motion, self.numerical_argument)
    end
  elseif as_function ~= nil and self.operator_got_motion_cb ~= nil then
    core.error("Expected motion but got Vim function")
  elseif as_function ~= nil then
    -- Just a normal bound key, probably.
    as_function(self, self.numerical_argument)

    if self.operator_got_motion_cb ~= nil then
      self.operator_name = text
      reset_keymap = false
    end
  elseif as_number ~= nil then
    -- Handle digits.
    if self.numerical_argument == nil then self.numerical_argument = 0 end
    self.numerical_argument = self.numerical_argument * 10 + as_number
    reset_numerical_argument = false
    reset_keymap = false
  elseif lookup_type == "nil" then
    core.error("Key %s not bound", text)
  else
    core.error("Something is wrong with the Vim if-else chain")
  end

  if reset_numerical_argument then self.numerical_argument = nil end
  if reset_keymap then self:set_correct_keymap() end

  if self.repeat_requested then
    self.repeat_requested = false
    self:repeat_commands(false)
  end
end

---@param control number
local function get_operator_selections_iter(invariant, control)
  local selection_invariant = invariant[1]
  local selection_iterator = invariant[2]
  local idx, l1, c1, l2, c2 = selection_iterator(selection_invariant, control)

  if not idx then
    return nil
  end

  ---@type vimxl.motion | nil
  local motion = invariant[3]
  local view = invariant[4]
  local numerical_argument = invariant[5]

  if motion then
    l1, c1, l2, c2 = motion(view.doc, l1, c1, view, numerical_argument)
  end

  return idx, l1, c1, l2, c2, 1
end

---@param doc core.doc
---@param control number
local function merged_selection_iter(doc, control)
  if control > 0 then return end

  ---@type number
  local start_line, start_col, end_line, end_col = #doc.lines + 1, 0, 0, 0

  -- How many were combined?
  local fused = 0

  for _, l1, c1, l2, c2 in doc:get_selections() do
    fused = fused + 1

    -- TODO: If only get_selections was typed properly, then ugly casts like these wouldn't exist ;>
    ---@cast l1 number

    if start_line > l1 or start_line == l1 and start_col > c1 then
      start_line, start_col = l1, c1
    end
    if start_line > l2 or start_line == l2 and start_col > c2 then
      start_line, start_col = l2, c2
    end
    if l1 > end_line or l1 == end_line and c1 > end_col then
      end_line, end_col = l1, c1
    end
    if l2 > end_line or l2 == end_line and c2 > end_col then
      end_line, end_col = l2, c2
    end
  end

  return control + 1, start_line, start_col, end_line, end_col, fused
end

---@param motion? vimxl.motion
---@param numerical_argument? number
function VimState:get_operator_selections(motion, numerical_argument)
  if self.mode == "v-line" and motion == nil then
     return merged_selection_iter, self.view.doc, 0
  end

  local selection_iter, selection_invariant, control = self.view.doc:get_selections(false, true)
  local invariant = { selection_invariant, selection_iter, motion, self.view, numerical_argument }
  return get_operator_selections_iter, invariant, control
end

---Call this if you want the entire command history
---to be repeatable with an arbitrary amount.
---Default is taken from the numerical_argument of the view.
---@param numerical_argument? number
function VimState:begin_repeatable_history(numerical_argument)
  table.insert(self.command_history, {
    ["type"] = "repeat_everything",
    ["number"] = numerical_argument or 1
  })
end

---The simple case where we just rerun the command
---n times... We do so by prepending a repeat_everything
---to the repeatable_commands array.
---@param perform vimxl.perform_no_number
---@param numerical_argument? number
function VimState:begin_naive_repeatable_command(perform, numerical_argument)
  if self.mode ~= "n" then
    table.insert(self.command_history, {
      ["type"] = "repeat_everything",
      ["number"] = numerical_argument or 1,
    })
    table.insert(self.command_history, {
      ["type"] = "command",
      ["perform"] = perform,
    })
    perform(self)
  else
    self.repeatable_commands = {
      {
        ["type"] = "repeat_everything",
        ["number"] = numerical_argument or 1,
      },
      {
        ["type"] = "command",
        ["perform"] = perform,
      }
    }

    self.repeat_requested = true
  end
end

---The most advanced case where the command decides by
---itself how it should handle the numerical argument.
---Note this is done so that the "." command can change this
---parameter by taking its own numerical_argument and
---substituting it in.
---@param perform vimxl.perform_with_optional_number
---@param numerical_argument? number
function VimState:begin_command_supporting_numerical_argument(perform, numerical_argument)
  if self.mode ~= "n" then
    table.insert(self.command_history, {
      ["type"] = "command_supporting_number",
      ["perform"] = perform,
      ["number"] = numerical_argument,
    })
    perform(self, numerical_argument)
  else
    self.repeatable_commands = {
      {
        ["type"] = "command_supporting_number",
        ["perform"] = perform,
        ["number"] = numerical_argument,
      }
    }

    self.repeat_requested = true
  end
end

---Do not call directly. Set requested_repeats instead.
---@param minus_one boolean Should we do one less repeat_everything?
function VimState:repeat_commands(minus_one)
  -- Not setting this to false could have disasterous rammification
  -- if repeat-commands is somehow called in i-mode.
  -- Which is to say, risk of recursive calls.
  self.track_primitives = false

  local n_times = 1
  local repeat_everything_seen = false
  local completed_iterations = 1
  if minus_one then completed_iterations = 2 end

  while n_times > 0 do
    n_times = n_times - 1
    for _, v in ipairs(self.repeatable_commands) do
      if v.type == "text_input" then
        self.view.doc:text_input(v.text)
      elseif v.type == "command" then
        v.perform(self)
      elseif v.type == "repeat_everything" then
        if not repeat_everything_seen then
          repeat_everything_seen = true
          n_times = v.number - completed_iterations
        end
        -- Otherwise a noop.
      elseif v.type == "command_supporting_number" then
        v.perform(self, v.number)
      elseif v.type == "select_to" then
        v.perform(self)
      elseif v.type == "move_to" then
        self.view.doc:move_to(v.translate, self)
      elseif v.type == "remove_text" then
        local _, _, l2, c2 = self.view.doc:get_selection_idx(1)
        local l1, c1 = self.view.doc:position_offset(l2, c2, -v.amount)
        self.view.doc:remove(l1, c1, l2, c2)
      else
        core.error("Unknown history type: %s", v.type)
      end
    end
  end
end

local empty_keymap_for_i_mode = {}

function VimState:set_correct_keymap()
  -- Clear it, otherwise we have to set keymap to
  -- a map containing motions. We don't want that as
  -- that is not the Vim behaviour.
  self.operator_got_motion_cb = nil

  if self.mode == "n" then
    self.keymap = vim_keymap.normal
  elseif self.mode == "v" then
    self.keymap = vim_keymap.visual
  elseif self.mode == "v-block" then
    self.keymap = vim_keymap.visual_block
  elseif self.mode == "v-line" then
    self.keymap = vim_keymap.visual_line
  elseif self.mode == "i" then
    self.keymap = empty_keymap_for_i_mode
  else
    core.error("VimState:set_correct_keymap() has gone insane")
  end
end

---@type vimxl.motion
local function translate_noop(_, line, col)
  return line, col
end

---@param mode vimxl.mode
function VimState:set_mode(mode)
  local prev_mode = self.mode
  self.mode = mode

  -- We don't want the user to think that we are slow.
  core.blink_reset()

  self:set_correct_keymap()
  if prev_mode == "n" and (mode == "i" or mode == "v" or mode == "v-block" or mode == "v-line") then
    -- During i and v we will track history. So make sure history is clean.
    self.command_history = {}

    -- Make the cursor actually select something.
    if mode == "v" or mode == "v-block" or mode == "v-line" then
      self:move_or_select(translate_noop, 0)
    end
  elseif mode == "n" then
    -- Send us back to where we started. Note that this is unlike doc:select-none 
    -- because doc:select-none sets the cursor to the end of the selection.
    if prev_mode == "v" or prev_mode == "v-block" then
      local l1, c1 = self.view.doc:get_selection()
      self.view.doc:set_selection(l1, c1 - 1)
    else
      local _, _, l2, c2 = self.view.doc:get_selection_idx(1)
      self.view.doc:set_selection(l2, c2)
    end

    -- We have to scan to see if there is a
    -- repeat_everything command in there and see if its
    -- number value is high enough to warrent a repeat.
    -- We also check if there are actual commands that do anything at all.
    local is_non_empty_history = false
    local repeat_everything_found = false
    local should_repeat = false
    for _, v in ipairs(self.command_history) do
      if is_non_empty_history and repeat_everything_found then
        -- We know everything we want to know now. No point
        -- in continuing.
        break
      elseif v.type == "repeat_everything" then
        repeat_everything_found = true
        if v.number > 1 then should_repeat = true end
      else
        is_non_empty_history = true
      end
    end

    -- Some history was recorded, so we can use that for the repeat command.
    if is_non_empty_history then
      self.repeatable_commands = self.command_history
    elseif prev_mode ~= "n" then
      -- It's sad that just entering i mode without doing anything
      -- will clear the repeat buffer in Vim. But that's how Vim is.
      -- But only if we are not just mashing the ESC button.
      self.repeatable_commands = {}
    end
    self.command_history = {}

    -- This is done so that 2oBLABLA<esc> works as expected.
    if is_non_empty_history and should_repeat then
      -- We've already done one iteration.
      -- But we must do another since the intention is to
      -- repeat at least two times.
      -- Passing true here makes sure we loop -1 times.
      self:repeat_commands(true)
    end
  end
end

function VimState:escape_mode()
  -- Copied from doc:select-none
  -- We want to deselect everything when escape is pressed more or less.
  -- We want to the last selection if possible.
  local l1, c1 = self.view.doc:get_selection_idx(self.view.doc.last_selection)
  if not l1 then
    l1, c1 = self.view.doc:get_selection_idx(1)
  end
  self.view.doc:set_selection(l1, c1)
  self:set_mode("n")
end

---@param docview_draw_caret fun(view: core.docview, x: number, y: number)
---@param x number
---@param y number
function VimState:draw_caret(docview_draw_caret, x, y)
    if self.mode == "i" or ime.editing then
      return docview_draw_caret(self.view, x, y)
    end

    -- Visual mode caret rendered in draw_overlay instead.
    if self.mode ~= "v" and self.mode ~= "v-block" then
      local lh = self.view:get_line_height()
      local w = self.view:get_font():get_width(" ")
      renderer.draw_rect(x, y, w, lh, style.caret)
    end
end

---@param state vimxl.vimstate
---@param not_blinking boolean
---@param l1 number
---@param c1 number
---@param l2 number
---@param c2 number
---@param min_line number
---@param max_line number
local function draw_cursor_for_selection(state, not_blinking, l1, c1, l2, c2, min_line, max_line)
    local in_viewport = l1 >= min_line and l1 <= max_line
    if in_viewport
    and system.window_has_focus()
    and not ime.editing
    and not_blinking then
      if is_selection_going_forward(l1, c1, l2, c2) then
        c1 = c1 - 1
      end

      -- Draw visual mode caret.
      local x, y = state.view:get_line_screen_position(l1, c1)
      local lh = state.view:get_line_height()
      local w = state.view:get_font():get_width(" ")
      renderer.draw_rect(x, y, w, lh, style.caret)
    end
end

function VimState:draw_overlay()
  if core.active_view ~= self.view then
    return
  end

  if self.mode ~= "v" and self.mode ~= "v-block" then
    return
  end

  local min_line, max_line = self.view:get_visible_line_range()
  local T = config.blink_period
  local not_blinking = config.disable_blink or (core.blink_timer - core.blink_start) % T < T / 2

  if self.mode == "v-block" then
    local l1, c1, l2, c2 = self.view.doc:get_selection()
    draw_cursor_for_selection(self, not_blinking, l1, c1, l2, c2, min_line, max_line)
    return
  end

  for _, l1, c1, l2, c2 in self.view.doc:get_selections() do
    draw_cursor_for_selection(self, not_blinking, l1, c1, l2, c2, min_line, max_line)
  end

end

-- We react to this in order to put us in visual mode
-- if a selection is made in normal mode.
function VimState:on_mouse_moved()
  if self.view.mouse_selecting and self.mode == "n" then
    self:set_mode("v")
  end
end

---@param button core.view.mousebutton
function VimState:on_mouse_pressed(button)
  -- TODO: Handle visual block select as well.
  if self.mode == "v" and button == "left" then
    self:escape_mode()
  end
end

return VimState
