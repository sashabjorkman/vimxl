-- mod-version:3

local core = require "core"
local command = require "core.command"
local DocView = require "core.docview"

local apply_docview_patches = require "plugins.vimxl.docview-patcher"
local apply_tracking_patches = require "plugins.vimxl.chronicle"
local apply_autocomplete_patches = require "plugins.vimxl.autocomplete-patcher"
local constants = require "plugins.vimxl.constants"
local vim_translate = require "plugins.vimxl.translate"
local VimState = require "plugins.vimxl.vimstate"

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
    core.active_view.vim_state:on_text_input("\n")
  end,
  ["vimxl:enter-block-mode"] = function ()
    core.active_view.vim_state:on_text_input(constants.CTRL_V)
  end
})

command.add(DocView, {
  ["vimxl:toggle-vi-mode"] = function ()
    local view = core.active_view
    if view.vim_state == nil then
      view.vim_state = VimState(view)
    else
      view.vim_state = nil
    end
  end
})

apply_tracking_patches()
apply_docview_patches()
apply_autocomplete_patches()
