-- mod-version:3

local core = require "core"
local common = require "core.common"
local config = require "core.config"
local command = require "core.command"
local style = require "core.style"
local DocView = require "core.docview"
local StatusView = require "core.statusview"

local apply_docview_patches = require "plugins.vimxl.docview-patcher"
local apply_tracking_patches = require "plugins.vimxl.chronicle"
local apply_autocomplete_patches = require "plugins.vimxl.autocomplete-patcher"
local constants = require "plugins.vimxl.constants"
local vim_translate = require "plugins.vimxl.translate"
local VimState = require "plugins.vimxl.vimstate"

local default_config = {
  disable_inside_plugins_folder = false,
}
default_config.config_spec = {
  name = "VimXL",
  {
    label = "Restricted VimXL Mode",
    description = "Automatically disable VimXL inside of the VimXL plugin folder",
    path = "disable_inside_plugins_folder", type = "TOGGLE",
    default = false,
  }
}

config.plugins.vimxl = common.merge(default_config, config.plugins.vimxl)


local function vim_mode_predicate()
  local view = core.active_view
  return view:extends(DocView) and view.vim_state ~= nil
end

-- TOOD: Handle special case enter to \n

command.add(vim_mode_predicate, {
  ["vimxl:escape-mode"] = function ()
    core.active_view.vim_state:escape_mode()
  end,
  ["vimxl:move-to-previous-char"] = function ()
    core.active_view.vim_state:move_or_select(vim_translate.previous_char)
  end,
  ["vimxl:move-to-next-char"] = function ()
    -- TODO: Should we clamp inside of normal mode? In that case maybe
    -- previous-char also shouldn't wrap in normal mode?
    -- Also mouse cursor clicks should be line-len clamped as well then...
    core.active_view.vim_state:move_or_select(vim_translate.next_char)
  end,
  ["vimxl:move-to-previous-line"] = function ()
    core.active_view.vim_state:move_or_select(DocView.translate.previous_line)
  end,
  ["vimxl:move-to-next-line"] = function ()
    core.active_view.vim_state:move_or_select(DocView.translate.next_line)
  end,
  ["vimxl:move-to-previous-page"] = function ()
    core.active_view.vim_state:move_or_select(DocView.translate.previous_page)
  end,
  ["vimxl:move-to-next-page"] = function ()
    core.active_view.vim_state:move_or_select(DocView.translate.next_page)
  end,
  ["vimxl:open-doc"] = function (_, file_name)
    -- TODO: file_name == "" should reload the file from disk.
    if file_name ~= "" and file_name ~= nil then
      core.root_view:open_doc(core.open_doc(common.home_expand(file_name)))
    end
  end,
})

local function vim_non_i_mode_predicate()
  local view = core.active_view
  return view:extends(DocView) and view.vim_state ~= nil and view.vim_state.mode ~= "i"
end

command.add(vim_non_i_mode_predicate, {
  ["vimxl:undo"] = function ()
    command.perform("doc:undo")
  end,
  ["vimxl:redo"] = function ()
    command.perform("doc:redo")
  end,
  ["vimxl:newline"] = function ()
    -- TODO: Newline in Vim has some special behaviour where it automatically clears empty lines behind it.
    core.active_view.vim_state:on_text_input("\n")
  end,
  ["vimxl:enter-block-mode"] = function ()
    core.active_view.vim_state:on_text_input(constants.CTRL_V)
  end,
  ["vimxl:close-or-quit"] = function ()
    local node = core.root_view:get_active_node()
    if node and (not node:is_empty() or not node.is_primary_node) then
      local do_close = function()
        node:remove_view(core.root_view.root_node, node.active_view)

        -- If this was the last one, then close all of LiteXL.
        if node:is_empty() then
          core.quit()
        end
      end
      node.active_view:try_close(do_close)
    else
      core.quit()
    end
  end,
  ["vimxl:force-close-or-quit"] = function()
    local node = core.root_view:get_active_node()
    if node and (not node:is_empty() or not node.is_primary_node) then
      node:remove_view(core.root_view.root_node, node.active_view)

      -- If this was the last one, then close all of LiteXL.
      if node:is_empty() then
        core.quit(true)
      end
    else
      core.quit(true)
    end
  end,
  ["vimxl:kill-view"] = function ()
    local node = core.root_view:get_active_node()
    if node and (not node:is_empty() or not node.is_primary_node) then
      local do_close = function()
        node:remove_view(core.root_view.root_node, node.active_view)
      end
      node.active_view:try_close(do_close)
    end
  end,
  ["vimxl:test"] = function ()
      core.log("test command exectued thanks")
  end,
})

command.add(DocView, {
  ["vimxl:toggle-vi-mode"] = function ()
    local view = core.active_view
    view.vim_was_here = true
    if view.vim_state == nil then
      view.vim_state = VimState(view)
    else
      view.vim_state = nil
    end
  end
})

local function vim_enabled_view_predicate()
  if core.active_view and core.active_view.vim_was_here then
    return true
  end
  return vim_mode_predicate()
end

if not core.status_view:get_item("vimxl:mode") then
  core.status_view:add_item({
    predicate = vim_enabled_view_predicate,
    name = "vimxl:mode",
    alignment = StatusView.Item.LEFT,
    get_item = function()
      local dv = core.active_view
      local text = "litexl mode"
      if dv and dv.vim_state then
        text = dv.vim_state:get_mode_name()
      end
      return {
        style.text, text
      }
    end,
    command = "vimxl:toggle-vi-mode",
    tooltip = "click to toggle vimxl"
  })
end

apply_tracking_patches()
apply_docview_patches()
apply_autocomplete_patches()
