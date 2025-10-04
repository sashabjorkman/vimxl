local core = require "core"
local command = require "core.command"

local operators = require "plugins.vimxl.operators"
local vim_translate = require "plugins.vimxl.translate"
local vim_motionmodes = require "plugins.vimxl.motionmodes"

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
    operators.generic_replace(state, operators.DELETE_STYLE_DISABLED, true, operators.PASTE_DISABLED, operators.CURSOR_SINGLE_LINE, vim_motionmodes.MOTION_MODE_CHARWISE)
    state:set_mode("n")
  end,
  ["vimxl-visual:substitute"] = function (state)
    operators.generic_replace(state, state.mode == "v-line" and operators.DELETE_STYLE_KEEP_LINE or operators.DELETE_STYLE_ALL, true, operators.PASTE_DISABLED, operators.CURSOR_MULTI_LINE, vim_motionmodes.MOTION_MODE_CHARWISE)
    state:set_mode("i")
    -- TODO: Support numerical arguments.
  end,
  ["vimxl-visual:change"] = function (state)
    operators.generic_replace(state, state.mode == "v-line" and operators.DELETE_STYLE_KEEP_LINE or operators.DELETE_STYLE_ALL, true, operators.PASTE_DISABLED, operators.CURSOR_MULTI_LINE, vim_motionmodes.MOTION_MODE_CHARWISE)
    state:set_mode("i")
  end,
  ["vimxl-visual:delete"] = function (state)
    operators.generic_replace(state, operators.DELETE_STYLE_ALL, true, operators.PASTE_DISABLED, operators.CURSOR_SINGLE_LINE, vim_motionmodes.MOTION_MODE_CHARWISE)
    state:set_mode("n")
  end,
  ["vimxl-visual:paste"] = function (start_state)
    start_state:begin_naive_repeatable_command(function (state)
      operators.generic_replace(state, operators.DELETE_STYLE_ALL, true, operators.PASTE_BEFORE_AND_MOVE, operators.CURSOR_SINGLE_LINE, vim_motionmodes.MOTION_MODE_CHARWISE)
      state:set_mode("n")
    end)
  end,
  ["vimxl-visual:indent"] = function (start_state, numerical_argument)
    operators.generic_visual_indent(start_state, numerical_argument, false)
  end,
  ["vimxl-visual:unindent"] = function (start_state, numerical_argument)
    operators.generic_visual_indent(start_state, numerical_argument, true)
  end,

  -- Visual block mode specifics

  ["vimxl-visual-block:append-to-start"] = function (state)
    -- In some ways this is an abuse of replace since we neither paste nor copy. But it behaves close enough to what we want.
    -- TODO: Change the bool to a CLIPBOARD style that is disabled or something like that.
    operators.generic_replace(state, operators.DELETE_STYLE_DISABLED, false, operators.PASTE_DISABLED, operators.CURSOR_MULTI_LINE, vim_motionmodes.MOTION_MODE_CHARWISE)
    state:set_mode("i")
    -- TODO: Exiting a multiline-edit from i-mode into n-mode should put us on the first line, not last line. But probably there are edge cases to this?
    -- TODO: Handle numerical argument.
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
  ["vimxl-normal:substitute"] = function (start_state, numerical_argument_operator)
    start_state:set_mode("i")
    start_state:begin_command_supporting_numerical_argument(function (state, numerical_argument)
        operators.generic_replace(state, operators.DELETE_STYLE_ALL, true, operators.PASTE_DISABLED, operators.CURSOR_SINGLE_LINE, vim_translate.right, numerical_argument or 1)
    end, numerical_argument_operator)
  end,
  ["vimxl-normal:insert-mode"] = function (state, numerical_argument)
    state:set_mode("i")
    state:begin_repeatable_history(numerical_argument)
  end,
  ["vimxl-normal:insert-mode-after"] = function (state, numerical_argument)
    state:set_mode("i")
    state:move_or_select(vim_translate.right)
    state:begin_repeatable_history(numerical_argument)
    -- TODO: for perfect vim-emulation we should add a left-translation into history but not execute it (or something like that to place the cursor at the right place in case of 3aAB<esc>)
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
    start_state:expect_motion(function (second_state, motion_mode, motion, numerical_argument_motion)
      local product_numerical_argument = product_with_strange_default(numerical_argument_operator, numerical_argument_motion)
      second_state:begin_command_supporting_numerical_argument(function (state, numerical_argument)
        local full_text = operators.generic_replace(state, operators.DELETE_STYLE_ALL, true, operators.PASTE_DISABLED, operators.CURSOR_SINGLE_LINE, motion_mode, motion, numerical_argument)
        if full_text:match("\n$") then
          -- We only want this for linewise motions which is why we detect \n.
          state:move_or_select(vim_translate.first_printable)
        end
      end, product_numerical_argument)
    end)
  end,
  ["vimxl-normal:change"] = function (start_state, numerical_argument_operator)
    start_state:expect_motion(function (second_state, motion_mode, motion, numerical_argument_motion)
      local product_numerical_argument = product_with_strange_default(numerical_argument_operator, numerical_argument_motion)
      second_state:set_mode("i")
      second_state:begin_command_supporting_numerical_argument(function (state, numerical_argument)
        operators.generic_replace(state, operators.DELETE_STYLE_KEEP_LINE, true, operators.PASTE_DISABLED, operators.CURSOR_SINGLE_LINE, motion_mode, motion, numerical_argument)
      end, product_numerical_argument)
    end)
  end,
  ["vimxl-normal:yank"] = function (state, numerical_argument_operator)
    state:expect_motion(function (second_state, motion_mode, motion, numerical_argument_motion)
      local product_numerical_argument = product_with_strange_default(numerical_argument_operator, numerical_argument_motion)
      operators.generic_replace(second_state, operators.DELETE_STYLE_DISABLED, true, operators.PASTE_DISABLED, operators.CURSOR_SINGLE_LINE, motion_mode, motion, product_numerical_argument)
    end)
  end,
  ["vimxl-normal:paste-before"] = function (start_state, numerical_argument)
    start_state:begin_naive_repeatable_command(function (state)
      operators.generic_replace(state, operators.DELETE_STYLE_DISABLED, false, operators.PASTE_BEFORE_AND_MOVE, operators.CURSOR_SINGLE_LINE, vim_motionmodes.MOTION_MODE_CHARWISE)
    end, numerical_argument)
  end,
  ["vimxl-normal:paste-after"] = function (start_state, numerical_argument)
    start_state:begin_naive_repeatable_command(function (state)
      operators.generic_replace(state, operators.DELETE_STYLE_DISABLED, false, operators.PASTE_AFTER_AND_MOVE, operators.CURSOR_SINGLE_LINE, vim_motionmodes.MOTION_MODE_CHARWISE)
    end, numerical_argument)
  end,
  ["vimxl-normal:indent"] = function (start_state, numerical_argument_operator)
    -- TODO: Use the same function is vimxl-visual:indent in the future.
    operators.generic_normal_indent(start_state, numerical_argument_operator, false)
  end,
  ["vimxl-normal:unindent"] = function (start_state, numerical_argument_operator)
    -- TODO: Use the same function is vimxl-visual:indent in the future.
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
      state:execute_command(text)
    end,
    suggest = function (text)
      -- We could have just done suggest = VimState.get_suggested_commands
      -- if we redefined get_suggested_commands to not take a self.
      -- But maybe in the future we will want view specific suggestions?
      return state:get_suggested_commands(text)
    end
    })
  end,
  ["vimxl-normal:argument-test"] = function (_, numerical_argument)
    core.error("Numerical argument: %s", numerical_argument)
  end,
}

return vim_functions
