local DocView = require "core.docview"
local common = require "core.common"
local VimState = require "plugins.vimxl.vimstate"

local vimxl_directory = USERDIR .. PATHSEP .. "plugins" .. PATHSEP .. "vimxl"

---@class core.docview
---@field vim_state vimxl.vimstate | nil If non-nil then Vim-mode has been enabled

-- Make sure DocView proxies some functions to VimState if there is one on the
-- current document.
local function apply_patches()

  local docview_new = DocView.new

  ---@param doc core.doc
  function DocView:new(doc)
    docview_new(self, doc)

    if doc.abs_filename and common.path_belongs_to(doc.abs_filename, vimxl_directory) then
      -- Don't open Vim-mode when developing VimXL as that could get annoying.
    else
      self.vim_state = VimState(self)
    end
  end

  local draw_caret = DocView.draw_caret
  function DocView:draw_caret(x, y)
    if self.vim_state then
      self.vim_state:draw_caret(draw_caret, x, y)
    else
      draw_caret(self, x, y)
    end
  end

  local on_text_input = DocView.on_text_input
  function DocView:on_text_input(text)
    if self.vim_state then
      self.vim_state:on_text_input(text)
    else
      on_text_input(self, text)
    end
  end

  local on_mouse_moved = DocView.on_mouse_moved
  function DocView:on_mouse_moved(...)
    on_mouse_moved(self, ...)
    if self.vim_state then
      self.vim_state:on_mouse_moved()
    end
  end

  local on_mouse_pressed = DocView.on_mouse_pressed
  function DocView:on_mouse_pressed(button, ...)
    if self.vim_state then
      self.vim_state:on_mouse_pressed(button)
    end
    on_mouse_pressed(self, button, ...)
  end

end

return apply_patches
