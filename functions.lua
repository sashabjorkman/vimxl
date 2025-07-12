local core = require "core"

local command = require "core.command"

local constants = require "plugins.vimxl.constants"

local vim_available_commands = require "plugins.vimxl.available-commands"

---A function that can be invoked through Vim keybinds.
---It can also be invoked through the command mode if put inside the 
-- vim_visible_commands table. 
---@alias vimxl.vim_command fun(view: vimxl.vimstate, numerical_argument: number | nil)

---All commands known to Vim.
---@type { [string]: vimxl.vim_command }
local vim_functions = {}

vim_functions = {
  -- Visual mode specifics

  ["v_yank"] = function (state)
    command.perform("doc:copy")
    state:set_mode("n")
  end,
  ["v_substitute"] = function (state)
    command.perform("doc:cut")
    state:set_mode("i")
  end,
  ["v_change"] = function (state)
    command.perform("doc:cut")
    state:set_mode("i")
  end,
  ["v_delete"] = function (state)
    command.perform("doc:cut")
    state:set_mode("n")
  end,

  -- Normal mode specifics

  ["visual_mode"] = function (state)
    state:set_mode("v")
  end,
  ["insert_mode"] = function (state, numerical_argument)
    state:set_mode("i")
    state:begin_repeatable_history(numerical_argument)
  end,
  ["append_to_start"] = function (state, numerical_argument)
    state:set_mode("i")
    state:begin_repeatable_history(numerical_argument)
    command.perform("doc:move-to-start-of-line")
  end,
  ["append_to_end"] = function (state, numerical_argument)
    state:set_mode("i")
    state:begin_repeatable_history(numerical_argument)
    command.perform("doc:move-to-end-of-line")
  end,
  ["newline_below"] = function (state, numerical_argument)
    state:set_mode("i")
    state:begin_repeatable_history(numerical_argument)
    command.perform("doc:newline-below")
  end,
  ["newline_above"] = function (state, numerical_argument)
    state:set_mode("i")
    state:begin_repeatable_history(numerical_argument)
    command.perform("doc:newline-above")
  end,
  ["delete"] = function (start_state, initial_numerical_argument)
    start_state:expect_motion(function (second_state, motion, initial_numerical_argument_motion)
      local product_numerical_argument = (initial_numerical_argument or 1) * (initial_numerical_argument_motion or 1)
      second_state:begin_command_with_numerical_argument(function (state, numerical_argument)
        state:yank_using_motion(motion, numerical_argument)
        for _, line, col in state.view.doc:get_selections(true) do
          state.view.doc:remove(motion(state.view.doc, line, col, state.view, numerical_argument))
        end
      end, product_numerical_argument)
    end)
  end,
  ["change"] = function (start_state, initial_numerical_argument)
    start_state:expect_motion(function (second_state, motion, initial_numerical_argument_motion)
      local product_numerical_argument = (initial_numerical_argument or 1) * (initial_numerical_argument_motion or 1)
      second_state:set_mode("i")
      second_state:begin_command_with_numerical_argument(function (state, numerical_argument)
        for _, line, col in state.view.doc:get_selections(true) do
          state.view.doc:remove(motion(state.view.doc, line, col, state.view, numerical_argument))
        end
      end, product_numerical_argument)
    end)
  end,
  ["yank"] = function (state, numerical_argument)
    state:expect_motion(function (second_state, motion, _)
      second_state:yank_using_motion(motion, numerical_argument)
    end)
  end,
  ["paste_before"] = function (start_state, numerical_argument)
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
  ["paste_after"] = function (start_state, numerical_argument)
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
        command.perform("doc:move-to-next-char")
        command.perform("doc:paste")
      end
    end, numerical_argument)
  end,
  ["repeat"] = function (state, numerical_argument)
    if numerical_argument ~= nil then
      for _, v in ipairs(state.repeatable_commands) do
        if v.type == "repeat_everything"
        or v.type == "command_with_number" then
          v.number = numerical_argument
          break
        end
      end
    end
    state.repeat_requested = true
  end,
  ["undo"] = function (_, numerical_argument)
    local count = numerical_argument or 1
    for _ = 1, count do
      command.perform("doc:undo")
    end
  end,
  ["find"] = function (state, _)
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
  ["repeat_find"] = function (state, numerical_argument)
    local count = numerical_argument or 1
    for _ = 1, count do
      command.perform("find-replace:repeat-find", state.view)
    end
  end,
  ["previous_find"] = function (state, numerical_argument)
    local count = numerical_argument or 1
    for _ = 1, count do
      command.perform("find-replace:previous-find", state.view)
    end
  end,
  ["command_mode"] = function (state)
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
