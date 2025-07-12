-- mod-version:3

local core = require "core"

local command = require "core.command"
local DocView = require "core.docview"

local apply_docview_patches = require "plugins.vimxl.docview-patcher"
local apply_tracking_patches = require "plugins.vimxl.chronicle"
local vim_translate = require "plugins.vimxl.translate"
local VimState = require "plugins.vimxl.vimstate"

local core_translate = require "core.doc.translate"


local core_translate_start_of_word = core_translate.start_of_word

---The idea here is to break start_of_word on purpose so that autocomplete
---no longer shows its ugly head on each keypress in Vim-mode.
---This is of course probably the ugliest hack in this codebase.
---@diagnostic disable-next-line: duplicate-set-field
function core_translate.start_of_word(doc, line, col)
  local view = core.active_view
  if view:extends(DocView) and view.vim_state ~= nil and view.vim_state.mode ~= "i" then
    return line, col
  else
    return core_translate_start_of_word(doc, line, col)
  end
end

---Normally used as a key inside of keymaps.
---It suppports numbers because that is how we encode special cases 
---like repeat motion names (yy) or a leading zero.
---@alias vimxl.lookup_name string|number

local function vim_mode_predicate()
  local view = core.active_view
  return view:extends(DocView) and view.vim_state ~= nil
end

command.add(vim_mode_predicate, {
  ["vimxl:escape-mode"] = function ()
    core.active_view.vim_state:escape_mode()
  end,
  ["vimxl:move-to-previous-char"] = function ()
    core.active_view.vim_state:move_or_select(vim_translate.previous_char)
  end,
  ["vimxl:move-to-next-char"] = function ()
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
  ["vimxl:undo"] = function ()
    command.perform("doc:undo")
  end,
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
