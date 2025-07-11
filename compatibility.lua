-- Force Lite-XL to work better with VimDocView

local core = require "core"

local command = require "core.command"

local VimDocView = require "plugins.vimxl.vimdocview"

---@param name string
local function wrap_predicate_for_vimdocview(name)
  local predicate = command.map[name].predicate
  command.map[name].predicate = function(...)
    if core.active_view:extends(VimDocView) then
      return true
    end
    return predicate(...)
  end
end

local function apply_patches ()
  -- These functions for some reason insist on a DocView. But we want them to work for VimDocView as well.
  -- So we wrap their predicates to allow our own view as well.
  wrap_predicate_for_vimdocview("find-replace:find")
  wrap_predicate_for_vimdocview("find-replace:repeat-find")
  wrap_predicate_for_vimdocview("find-replace:previous-find")
end

return apply_patches
