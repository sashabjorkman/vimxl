local core = require "core"
local core_translate = require "core.doc.translate"
local command = require "core.command"
local DocView = require "core.docview"
local Doc = require "core.doc"

local function in_vim_mode(view, doc)
  return view:extends(DocView) and view.doc == doc and view.vim_state ~= nil
end

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
    end
    old_complete_perform(dv)
    if in_vim_mode(dv, dv.doc) then
      dv.vim_state.track_primitives = false
    end
  end
end

return apply_patches
