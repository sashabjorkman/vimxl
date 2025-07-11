local vim_translate = require "plugins.vimxl.translate"

---A Vim motion that can be used either by a vim_command calling expect_motion,
---Or directly by putting it into a keymap, in which case it will either move
---or select depending on the current mode.
---@alias vimxl.motion fun(doc: core.doc, line: number, col: number, view: vimxl.vimdocview, numerical_argument: number | nil): number, number, number | nil, number | nil

---Contains all known Vim motions.
---This is the only place where motions can be placed.
---If they are placed outside of this table then they will
---not be treated as such.
---
---There are some slight differences between
---how motions work in normal/visual mode and how
---they work as arguments to an operator.
---As such, the motions prefixed with go_ are for
---those that exhibit normal/visual behaviour.
---There is some duplication but that is just
---for the sake of symmetry.
---@type { [string]: vimxl.motion }
local vim_motions = {

  -- Vim motions.
  ["vimxlmotion:end_of_line"] = vim_translate.end_of_line,
  ["vimxlmotion:first_col"] = vim_translate.start_of_line,
  ["vimxlmotion:nth_col"] = vim_translate.nth_col,
  ["vimxlmotion:first_printable"] = vim_translate.first_printable,
  ["vimxlmotion:nth_line_printable"] = vim_translate.cursor_to_nth_line_printable,
  ["vimxlmotion:line_by_number"] = vim_translate.select_entire_line_by_number,
  ["vimxlmotion:start_of_documen_"] = vim_translate.current_line_to_doc_start_or_line,
  ["vimxlmotion:next_word"] = vim_translate.next_word_start,
  ["vimxlmotion:next_word_by_whitespace"] = vim_translate.next_word_start_by_whitespace,
  ["vimxlmotion:prev_word"] = vim_translate.prev_word_start,
  ["vimxlmotion:prev_word_by_whitespace"] = vim_translate.prev_word_start_by_whitespace,
  ["vimxlmotion:up"] = vim_translate.up,
  ["vimxlmotion:down"] = vim_translate.down,
  ["vimxlmotion:left"] = vim_translate.left,
  ["vimxlmotion:right"] = vim_translate.right,
  ["vimxlmotion:select_inner_word"] = vim_translate.inner_word,
  ["vimxlmotion:entire_current_line_or_more"] = vim_translate.entire_current_line_or_more,

  -- Normal and visual mode navigation.
  ["vimxlmotion:go_end_of_line"] = vim_translate.end_of_line,
  ["vimxlmotion:go_first_col"] = vim_translate.start_of_line,
  ["vimxlmotion:go_nth_col"] = vim_translate.nth_col,
  ["vimxlmotion:go_first_printable"] = vim_translate.first_printable,
  ["vimxlmotion:go_nth_line_printable"] = vim_translate.cursor_to_nth_line_printable,
  ["vimxlmotion:go_line_by_number"] = vim_translate.goto_line_by_number, -- Differs
  ["vimxlmotion:go_start_of_document"] = vim_translate.start_of_doc_or_line, -- Differs
  ["vimxlmotion:go_next_word"] = vim_translate.next_word_start_multiline, -- Differs
  ["vimxlmotion:go_next_word_by_whitespace"] = vim_translate.next_word_start_by_whitespace_multiline, -- Differs
  ["vimxlmotion:go_prev_word"] = vim_translate.prev_word_start,
  ["vimxlmotion:go_prev_word_by_whitespace"] = vim_translate.prev_word_start_by_whitespace,
  ["vimxlmotion:go_up"] = vim_translate.up,
  ["vimxlmotion:go_down"] = vim_translate.down,
  ["vimxlmotion:go_left"] = vim_translate.left,
  ["vimxlmotion:go_right"] = vim_translate.right,
}

return vim_motions
