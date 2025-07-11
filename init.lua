-- mod-version:3

local core = require "core"

local command = require "core.command"
local DocView = require "core.docview"

local apply_compatibility_patches = require "plugins.vimxl.compatibility"
local apply_tracking_patches = require "plugins.vimxl.chronicle"
local vim_translate = require "plugins.vimxl.translate"
local VimDocView = require "plugins.vimxl.vimdocview"

---Normally used as a key inside of keymaps.
---It suppports numbers because that is how we encode special cases 
---like repeat motion names (yy) or a leading zero.
---@alias vimxl.lookup_name string|number

-- TODO: Replace with command.add(nil, ...) once that change is done to Lite-XL.
local function always_true() return true end
command.add(always_true, {
  ["vimxl:open-doc"] = function ()
    local node = core.root_view:get_active_node_default()
    local doc = core.open_doc("examplevim.txt")
    node:add_view(VimDocView(doc))
  end,
})

command.add(VimDocView, {
  ["vimxl:escape-mode"] = function ()
    core.active_view:escape_mode()
  end,
  ["vimxl:move-to-previous-char"] = function ()
    core.active_view:move_or_select(vim_translate.previous_char)
  end,
  ["vimxl:move-to-next-char"] = function ()
    core.active_view:move_or_select(vim_translate.next_char)
  end,
  ["vimxl:move-to-previous-line"] = function ()
    core.active_view:move_or_select(DocView.translate.previous_line)
  end,
  ["vimxl:move-to-next-line"] = function ()
    core.active_view:move_or_select(DocView.translate.next_line)
  end,
  ["vimxl:move-to-previous-page"] = function ()
    core.active_view:move_or_select(DocView.translate.previous_page)
  end,
  ["vimxl:move-to-next-page"] = function ()
    core.active_view:move_or_select(DocView.translate.next_page)
  end,
  ["vimxl:undo"] = function ()
    command.perform("doc:undo")
  end,
})

command.add(DocView, {
  ["vimxl:toggle-vi-mode"] = function ()
    local new_view = core.active_view
    if new_view:extends(VimDocView) then
      new_view = DocView(new_view.doc)
    elseif new_view:extends(DocView) then
      new_view = VimDocView(new_view.doc)
    end
    -- TODO: We could stash away the old type or view somewhere to better restore.
    -- But that is a problem for another day.

    local node = core.root_view.root_node:get_node_for_view(core.active_view)
    for i, view in ipairs(node.views) do
      if view == core.active_view then
        node.views[i] = new_view

        -- Make the transition seamless.
        new_view.scroll = view.scroll
        node:set_active_view(node.views[i])
        break
      end
    end
  end
})

apply_tracking_patches()
apply_compatibility_patches()
