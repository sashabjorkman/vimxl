local core = require "core"
local command = require "core.command"

local constants = require "plugins.vimxl.constants"
local operators = require "plugins.vimxl.operators"
local vim_available_commands = require "plugins.vimxl.available-commands"
local vim_translate = require "plugins.vimxl.translate"

---A function that can be invoked through Vim keybinds.
---It can also be invoked through the command mode if put inside the 
-- vim_visible_commands table. 
---@alias vimxl.vim_command fun(view: vimxl.vimstate, numerical_argument: number | nil)

---All commands known to Vim.
---@type { [string]: vimxl.vim_command }
local vim_functions = {}

-- An alias is defined because we use it so often.
local product_with_strange_default = operators.product_with_strange_default

vim_functions = {
  -- Visual mode specifics

  ["vimxl-visual:normal-mode"] = function (state)
    state:escape_mode()
  end,
  ["vimxl-visual:yank"] = function (state)
    -- TODO: Doesn't work exactly like Vim when using visual block select, try pasting.
    operators.generic_cut_or_copy(state, operators.DELETE_STYLE_DISABLED)
    state:set_mode("n")
  end,
  ["vimxl-visual:substitute"] = function (state)
    -- TODO: Doesn't work exactly like Vim when using visual block select, try pasting.
    operators.generic_cut_or_copy(state, state.mode == "v-line" and operators.DELETE_STYLE_KEEP_LINE or operators.DELETE_STYLE_ALL)
    state:set_mode("i")
  end,
  ["vimxl-visual:change"] = function (state)
    -- TODO: Doesn't work exactly like Vim when using visual block select, try pasting.
    operators.generic_cut_or_copy(state, state.mode == "v-line" and operators.DELETE_STYLE_KEEP_LINE or operators.DELETE_STYLE_ALL)
    state:set_mode("i")
  end,
  ["vimxl-visual:delete"] = function (state)
    -- TODO: Doesn't work exactly like Vim when using visual block select, try pasting.
    operators.generic_cut_or_copy(state, operators.DELETE_STYLE_ALL)
    state:set_mode("n")
  end,
  ["vimxl-visual:indent"] = function (start_state, numerical_argument)
    operators.generic_visual_indent(start_state, numerical_argument, false)
  end,
  ["vimxl-visual:unindent"] = function (start_state, numerical_argument)
    operators.generic_visual_indent(start_state, numerical_argument, true)
  end,

  -- Visual block mode specifics

  ["vimxl-visual-block:append-to-start"] = function (state)
    -- TODO: Handle numerical argument.
    -- TODO: Exiting should put us back where we started, not the end of the multiline edit.
    -- TODO: Same applies to delete and other commands for that matter.
    state:set_mode("i")
    local _, c1, _, c2 = state.view.doc:get_selection()
    state:move_or_select(vim_translate.nth_col, math.min(c1, c2))
  end,

  -- Normal mode specifics

  ["vimxl-normal:visual-mode"] = function (state)
    state:set_mode("v")
  end,
  ["vimxl-normal:visual-line-mode"] = function (state)
    state:set_mode("v-line")
  end,
  ["vimxl-normal:visual-block-mode"] = function (state)
    state:set_mode("v-block")
  end,
  ["vimxl-normal:insert-mode"] = function (state, numerical_argument)
    state:set_mode("i")
    state:begin_repeatable_history(numerical_argument)
  end,
  ["vimxl-normal:append-to-start"] = function (state, numerical_argument)
    state:set_mode("i")
    state:begin_repeatable_history(numerical_argument)
    state:move_or_select(vim_translate.first_printable)
  end,
  ["vimxl-normal:append-to-end"] = function (state, numerical_argument)
    state:set_mode("i")
    state:begin_repeatable_history(numerical_argument)
    command.perform("doc:move-to-end-of-line")
  end,
  ["vimxl-normal:newline-below"] = function (state, numerical_argument)
    state:set_mode("i")
    state:begin_repeatable_history(numerical_argument)
    command.perform("doc:newline-below")
  end,
  ["vimxl-normal:newline-above"] = function (state, numerical_argument)
    state:set_mode("i")
    state:begin_repeatable_history(numerical_argument)
    command.perform("doc:newline-above")
  end,
  ["vimxl-normal:delete"] = function (start_state, numerical_argument_operator)
    start_state:expect_motion(function (second_state, motion, numerical_argument_motion)
      local product_numerical_argument = product_with_strange_default(numerical_argument_operator, numerical_argument_motion)
      second_state:begin_command_supporting_numerical_argument(function (state, numerical_argument)
        local full_text = operators.generic_cut_or_copy(state, operators.DELETE_STYLE_ALL, motion, numerical_argument)
        if full_text:match("\n$") then
          -- We only want this for linewise motions which is why we detect \n.
          state:move_or_select(vim_translate.first_printable)
        end
      end, product_numerical_argument)
    end)
  end,
  ["vimxl-normal:change"] = function (start_state, numerical_argument_operator)
    start_state:expect_motion(function (second_state, motion, numerical_argument_motion)
      local product_numerical_argument = product_with_strange_default(numerical_argument_operator, numerical_argument_motion)
      second_state:set_mode("i")
      second_state:begin_command_supporting_numerical_argument(function (state, numerical_argument)
        operators.generic_cut_or_copy(state, operators.DELETE_STYLE_KEEP_LINE, motion, numerical_argument)
      end, product_numerical_argument)
    end)
  end,
  ["vimxl-normal:yank"] = function (state, numerical_argument_operator)
    state:expect_motion(function (second_state, motion, numerical_argument_motion)
      local product_numerical_argument = product_with_strange_default(numerical_argument_operator, numerical_argument_motion)
      operators.generic_cut_or_copy(second_state, operators.DELETE_STYLE_DISABLED, motion, product_numerical_argument)
    end)
  end,
  ["vimxl-normal:paste-before"] = function (start_state, numerical_argument)
    start_state:begin_naive_repeatable_command(function (state)
      local clip = system.get_clipboard()
      if clip:match("\n$") then
        -- Adapted from doc:newline-below
        for idx, line in state.view.doc:get_selections(false, true) do
          local indent = clip:match(constants.LEADING_INDENTATION_REGEX)
          state.view.doc:insert(line, 0, clip)
          state.view.doc:set_selections(idx, line, string.ulen(indent) + 1)
        end
      else
        command.perform("doc:paste")
      end
    end, numerical_argument)
  end,
  ["vimxl-normal:paste-after"] = function (start_state, numerical_argument)
    start_state:begin_naive_repeatable_command(function (state)
      local clip = system.get_clipboard()
      if clip:match("\n$") then
        -- Adapted from doc:newline-below
        for idx, line in state.view.doc:get_selections(false, true) do
          local indent = clip:match(constants.LEADING_INDENTATION_REGEX)
          state.view.doc:insert(line, math.huge, "\n" .. clip:sub(1, -2))
          state.view.doc:set_selections(idx, line + 1, string.ulen(indent) + 1)
        end
      else
        -- We use vim_translate.right instead of doc:move-to-next-char
        -- because move-to-next-char will wrap to the next line which is
        -- unwanted behaviour in this case.
        start_state:move_or_select(vim_translate.right)
        command.perform("doc:paste")
      end
    end, numerical_argument)
  end,
  ["vimxl-normal:indent"] = function (start_state, numerical_argument_operator)
    operators.generic_normal_indent(start_state, numerical_argument_operator, false)
  end,
  ["vimxl-normal:unindent"] = function (start_state, numerical_argument_operator)
    operators.generic_normal_indent(start_state, numerical_argument_operator, true)
  end,
  ["vimxl-normal:repeat"] = function (state, numerical_argument)
    if numerical_argument ~= nil then
      for _, v in ipairs(state.repeatable_commands) do
        if v.type == "repeat_everything"
        or v.type == "command_supporting_number" then
          v.number = numerical_argument
          break
        end
      end
    end
    state.repeat_requested = true
  end,
  ["vimxl-normal:undo"] = function (state, numerical_argument)
    local count = numerical_argument or 1
    for _ = 1, count do
      command.perform("doc:undo")
    end
    if state.mode == "n" then
      -- Call this because we want to collapse any sections that LiteXL might have restored
      -- during doc:undo.
      state:escape_mode()
      -- TODO: Use an actual function for this instead. ^
    end
  end,
  ["vimxl-normal:find"] = function (state, _)
    command.perform("find-replace:find", state.view)
    -- Since find-replace:find doesn't "block" we can't simply do:
    -- local count = numerical_argument or 1
    -- for _ = 1, count - 1 do
    --   command.perform("find-replace:repeat-find")
    -- end
    -- In order to emulate something like 3/blabla<enter>
    -- This is a flaw. But I'm not sure what the alternative is. 
    -- Maybe hijack something in find-replace? Or we could implement our own...
    -- TODO: Either way, fix this!
  end,
  ["vimxl-normal:repeat-find"] = function (state, numerical_argument)
    local count = numerical_argument or 1
    for _ = 1, count do
      command.perform("find-replace:repeat-find", state.view)
    end
  end,
  ["vimxl-normal:previous-find"] = function (state, numerical_argument)
    local count = numerical_argument or 1
    for _ = 1, count do
      command.perform("find-replace:previous-find", state.view)
    end
  end,
  ["vimxl-normal:command-mode"] = function (state)
    core.command_view:enter("Command", {
    submit = function(text)
      local lookup = vim_available_commands[text]

      if lookup == nil then
        core.error("Unknown command: " .. text)
      elseif vim_functions[lookup] then
          vim_functions[lookup](state, nil)
      elseif  command.map[lookup] then
        command.perform(lookup, state.view)
      else
        core.error("Unknown command: " .. text)
      end
    end,
    suggest = function (text)
      local res = {}
      local i = 0
      for k, v in pairs(vim_available_commands) do
        if k:sub(1, #text) == text then
          i = i + 1
          res[i] = {
            text = k,
            info = v
          }
        end
      end
      return res
    end
    })
  end,
}

return vim_functions
