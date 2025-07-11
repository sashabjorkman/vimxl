local core = require "core"

local command = require "core.command"

local constants = require "plugins.vimxl.constants"

local vim_available_commands = require "plugins.vimxl.available-commands"

---A function that can be invoked through Vim keybinds.
---It can also be invoked through the command mode if put inside the 
-- vim_visible_commands table. 
---@alias vimxl.vim_command fun(view: vimxl.vimdocview, numerical_argument: number | nil)

---All commands known to Vim.
---@type { [string]: vimxl.vim_command }
local vim_functions = {}

vim_functions = {
  -- Visual mode specifics

  ["v_yank"] = function (view)
    command.perform("doc:copy")
    view:set_mode("n")
  end,
  ["v_substitute"] = function (view)
    command.perform("doc:cut")
    view:set_mode("i")
  end,
  ["v_change"] = function (view)
    command.perform("doc:cut")
    view:set_mode("i")
  end,
  ["v_delete"] = function (view)
    command.perform("doc:cut")
    view:set_mode("n")
  end,

  -- Normal mode specifics

  ["visual_mode"] = function (view)
    view:set_mode("v")
  end,
  ["insert_mode"] = function (view, numerical_argument)
    view:set_mode("i")
    view:begin_repeatable_history(numerical_argument)
  end,
  ["append_to_start"] = function (view, numerical_argument)
    view:set_mode("i")
    view:begin_repeatable_history(numerical_argument)
    command.perform("doc:move-to-start-of-line")
  end,
  ["append_to_end"] = function (view, numerical_argument)
    view:set_mode("i")
    view:begin_repeatable_history(numerical_argument)
    command.perform("doc:move-to-end-of-line")
  end,
  ["newline_below"] = function (view, numerical_argument)
    view:set_mode("i")
    view:begin_repeatable_history(numerical_argument)
    command.perform("doc:newline-below")
  end,
  ["newline_above"] = function (view, numerical_argument)
    view:set_mode("i")
    view:begin_repeatable_history(numerical_argument)
    command.perform("doc:newline-above")
  end,
  ["delete"] = function (view, initial_numerical_argument)
    view:expect_motion(function (m_view, motion, initial_numerical_argument_motion)
      local product_numerical_argument = (initial_numerical_argument or 1) * (initial_numerical_argument_motion or 1)
      local function perform(yank_view, numerical_argument)
        yank_view:yank_using_motion(motion, numerical_argument)
        for _, line, col in yank_view.doc:get_selections(true) do
          yank_view.doc:remove(motion(yank_view.doc, line, col, yank_view, numerical_argument))
        end
      end
      m_view:begin_command_with_numerical_argument(perform, product_numerical_argument)
    end)
  end,
  ["change"] = function (view, initial_numerical_argument)
    view:expect_motion(function (m_view, motion, initial_numerical_argument_motion)
      local product_numerical_argument = (initial_numerical_argument or 1) * (initial_numerical_argument_motion or 1)
      m_view:set_mode("i")
      local function perform(c_view, numerical_argument)
        for _, line, col in c_view.doc:get_selections(true) do
          c_view.doc:remove(motion(c_view.doc, line, col, c_view, numerical_argument))
        end
      end
      m_view:begin_command_with_numerical_argument(perform, product_numerical_argument)
    end)
  end,
  ["yank"] = function (view, numerical_argument)
    view:expect_motion(function (m_view, motion)
      m_view:yank_using_motion(motion, numerical_argument)
    end)
  end,
  ["paste_before"] = function (view, numerical_argument)
    local function perform()
      local clip = system.get_clipboard()
      if clip:match("\n$") then
        -- Adapted from doc:newline-below
        for idx, line in view.doc:get_selections(false, true) do
          local indent = clip:match(constants.LEADING_INDENTATION_REGEX)
          view.doc:insert(line, 0, clip)
          view.doc:set_selections(idx, line, string.ulen(indent) + 1)
        end
      else
        command.perform("doc:paste")
      end
    end

    view:begin_naive_repeatable_command(perform, numerical_argument)
  end,
  ["paste_after"] = function (view, numerical_argument)
    local function perform()
      local clip = system.get_clipboard()
      if clip:match("\n$") then
        -- Adapted from doc:newline-below
        for idx, line in view.doc:get_selections(false, true) do
          local indent = clip:match(constants.LEADING_INDENTATION_REGEX)
          view.doc:insert(line, math.huge, "\n" .. clip:sub(1, -2))
          view.doc:set_selections(idx, line + 1, string.ulen(indent) + 1)
        end
      else
        command.perform("doc:move-to-next-char")
        command.perform("doc:paste")
      end
    end

    view:begin_naive_repeatable_command(perform, numerical_argument)
  end,
  ["repeat"] = function (view, numerical_argument)
    if numerical_argument ~= nil then
      for _, v in ipairs(view.repeatable_commands) do
        if v.type == "repeat_everything"
        or v.type == "command_with_number" then
          v.number = numerical_argument
          break
        end
      end
    end
    view.repeat_requested = true
  end,
  ["undo"] = function (_, numerical_argument)
    local count = numerical_argument or 1
    for _ = 1, count do
      command.perform("doc:undo")
    end
  end,
  ["find"] = function (view, _)
    command.perform("find-replace:find", view)
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
  ["repeat_find"] = function (view, numerical_argument)
    local count = numerical_argument or 1
    for _ = 1, count do
      command.perform("find-replace:repeat-find", view)
    end
  end,
  ["previous_find"] = function (view, numerical_argument)
    local count = numerical_argument or 1
    for _ = 1, count do
      command.perform("find-replace:previous-find", view)
    end
  end,
  ["command_mode"] = function (view)
    core.command_view:enter("Command", {
    submit = function(text)
      local lookup = vim_available_commands[text]

      if lookup == nil then
        core.error("Unknown command: " .. text)
      elseif vim_functions[lookup] then
          vim_functions[lookup](view, nil)
      elseif  command.map[lookup] then
        command.perform(lookup, view)
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
