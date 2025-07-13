local core = require "core"
local core_translate = require "core.doc.translate"
local command = require "core.command"
local Doc = require "core.doc"
local DocView = require "core.docview"

local function in_vim_mode(view, doc)
  return view:extends(DocView) and view.doc == doc and view.vim_state ~= nil
end

-- For autocomplete to work properly with the "." repeat command we need
-- to employ some hacks. 
local function apply_patches()
  local core_translate_start_of_word = core_translate.start_of_word

  ---The idea here is to break start_of_word on purpose so that autocomplete
  ---no longer shows its ugly head on each keypress in Vim-mode.
  ---This is of course probably the ugliest hack in this codebase.
  ---@diagnostic disable-next-line: duplicate-set-field
  function core_translate.start_of_word(doc, line, col)
    local view = core.active_view
    if in_vim_mode(view, doc) and view.vim_state.mode ~= "i" then
      return line, col
    else
      return core_translate_start_of_word(doc, line, col)
    end
  end

  local doc_insert = Doc.insert

  ---We patch insert & remove to be trackable if a certain flag is set
  ---for the sole purpose of being able to properly track the
  ---item.onselect behaviour of the autocomplete plugin.
  ---It also seemed less invasive than copying the entire autocomplete plugin
  ---and replacing it with our own 1984 style.
  ---@diagnostic disable-next-line: duplicate-set-field
  function Doc:insert(line, col, text)
    local view = core.active_view
    if in_vim_mode(view, self) and view.vim_state.mode == "i" and view.vim_state.track_primitives then
      ---@type vimxl.vimstate
      local vim_state = view.vim_state

      table.insert(vim_state.command_history, {
        ["type"] = "text_input",
        ["text"] = text,
      })
    end
    doc_insert(self, line, col, text)
  end

  -- TODO: We should give up if line1, col1 jumps all over the place.

  local doc_remove = Doc.remove
  ---@diagnostic disable-next-line: duplicate-set-field
  function Doc:remove(line1, col1, line2, col2)
    local view = core.active_view
    if in_vim_mode(view, self) and view.vim_state.mode == "i" and view.vim_state.track_primitives then
      ---@type vimxl.vimstate
      local vim_state = view.vim_state

      local text = self:get_text(line1, col1, line2, col2)
      table.insert(vim_state.command_history, {
        ["type"] = "remove_text",
        ["amount"] = #text,
      })
    end
    doc_remove(self, line1, col1, line2, col2)
  end

  local old_complete_perform = command.map["autocomplete:complete"].perform
  command.map["autocomplete:complete"].perform = function (dv)
    ---@cast dv core.docview
    if in_vim_mode(dv, dv.doc) then
      dv.vim_state.track_primitives = true
      old_complete_perform(dv)
      dv.vim_state.track_primitives = false
    else
      old_complete_perform(dv)
    end
  end

  local old_cancel_perform = command.map["autocomplete:cancel"].perform
  command.map["autocomplete:cancel"].perform = function (dv)
    old_cancel_perform()

    -- It is support annoying having to press escape-twice due to autocomplete.
    -- So we just leave directly. Question is, should we expose some other 
    -- alternative so that our dear users could bind some other key?
    if in_vim_mode(dv, dv.doc) then
      dv.vim_state:escape_mode()
    end
  end
end

return apply_patches
