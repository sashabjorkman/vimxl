local command = require "core.command"

local VimDocView = require "plugins.vimxl.vimdocview"

-- This file is concerned with patching existing Lite-XL commands to make it
-- possible to track the execution of these commands so that they may be
-- replayed.

---More or less only used by the patched Lite-XL commands.
---Do not use for other purposes as it creates more lambdas
---than is necessary.
---@param view vimxl.vimdocview
---@param perform fun(view: vimxl.vimdocview, ...: any)
local function add_patched_command_to_history(view, perform, ...)
  -- Save the argument so that we can replay accurately.
  local arg = {...}
  table.insert(view.command_history, {
    ["type"] = "command",
    ["perform"] = function (perform_view)
      perform(perform_view, table.unpack(arg))
    end,
  })
end

local untracked_commands = {
  ["doc:save"] = true,
  ["doc:save-as"] = true,
  ["doc:reload"] = true,
  ["doc:toggle-line-endings"] = true,
  ["doc:toggle-block-comments"] = true,
}

---@param v core.command.command
local function patch_command_give_up(_, v)
  local old_perform = v.old_perform or v.perform
  v.old_perform = old_perform
  v.perform = function(dv, ...)
  if dv:extends(VimDocView) and dv.mode ~= "n" then
    -- Just trash the repeat. No point in trying.
    -- And throw us back into normal mode.
    dv.command_history = {}
    dv:set_mode("n")
  end
  old_perform(dv, ...)
  end
end

---@param v core.command.command
local function patch_command_trash_history(_, v)
  local old_perform = v.old_perform or v.perform
  v.old_perform = old_perform

  v.perform = function(dv, ...)
    if dv:extends(VimDocView) and dv.mode ~= "n" then
      -- Just trash the repeat. No point in trying.
      dv.command_history = {}
    end
    old_perform(dv, ...)
  end
end

---@param k string
---@param v core.command.command
local function patch_command_for_tracking(k, v)
  -- TODO: The following is an ugly hack to satisfy the type-checker,
  -- ideally we'd store this information somewhere smarter:

  ---@class core.command.command
  ---@field old_perform fun(...: any)

  if k == "doc:undo"
  or k == "doc:redo" then
    patch_command_give_up(k, v)
    return
  end

  -- These commands don't throw us back into normal mode
  -- But they are completely hopless to track, so we just abandon
  -- that idea.
  if k == "doc:select-to-cursor"
  or k == "doc:split-cursor"
  or k == "doc:set-cursor"
  or k == "doc:set-cursor-word"
  or k == "doc:set-cursor-line" then
    patch_command_trash_history(k, v)
    return
  end

  local old_perform = v.old_perform or v.perform
  v.old_perform = old_perform

  v.perform = function (dv, ...)
    --core.error("Command intercepted: %s", k)
    if dv:extends(VimDocView) then
      if dv.mode == "i" then
        add_patched_command_to_history(dv, old_perform, ...)
      elseif dv.mode == "v" then
        -- Make all doc commands into noops when in visual mode.
        -- Except for doc:cut and doc:copy. We track and allow those.
        if k == "doc:cut" or k == "doc:copy" then
          -- Record it.
          add_patched_command_to_history(dv, old_perform, ...)
        else
          -- Don't do anything special.
          return
        end
      elseif dv.mode == "n" and k ~= "doc:move-to-next-char" and k ~= "doc:paste" then
        -- All doc commands in normal mode should probably be ignored.
        -- Except for those commands that our n commands try to perform.
        return
      end
    end
    old_perform(dv, ...)
  end
end


-- TODO: Handle snippets and autocomplete correctly.
-- TODO: Also handle find and replace.
local function apply_patches()
  for k, v in pairs(command.map) do
    if untracked_commands[k] then
      -- Noop
    elseif k:match("^doc:")
    or k:match("^reflow:")
    or k:match("^quote:")
    or k == "lsp:goto-implementation" then
      patch_command_for_tracking(k, v)
    elseif k:match("^trim-whitespace:") or k:match("^indent:") then
      patch_command_give_up(k, v)
    elseif k:match("^lint+") then
      patch_command_trash_history(k, v)
    end
  end
end

return apply_patches
