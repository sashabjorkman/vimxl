local vim_translate = require "plugins.vimxl.translate"

---A Vim motion that can be used either by a vim_command calling expect_motion,
---Or directly by putting it into a keymap, in which case it will either move
---or select depending on the current mode.
---@alias vimxl.motion fun(doc: core.doc, line: number, col: number, view: core.docview, numerical_argument: number | nil): number, number, number | nil, number | nil

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
  ["vimxl-motion:end-of-line"] = vim_translate.end_of_line,
  ["vimxl-motion:first-col"] = vim_translate.start_of_line,
  ["vimxl-motion:nth-col"] = vim_translate.nth_col,
  ["vimxl-motion:first-printable"] = vim_translate.first_printable,
  ["vimxl-motion:nth-line-printable"] = vim_translate.cursor_to_nth_line_printable,
  ["vimxl-motion:line-by-number"] = vim_translate.select_entire_line_by_number,
  ["vimxl-motion:start-of-document"] = vim_translate.current_line_to_doc_start_or_line,
  ["vimxl-motion:next-word"] = vim_translate.next_word_start,
  ["vimxl-motion:next-word-by-whitespace"] = vim_translate.next_word_start_by_whitespace,
  ["vimxl-motion:prev-word"] = vim_translate.prev_word_start,
  ["vimxl-motion:prev-word-by-whitespace"] = vim_translate.prev_word_start_by_whitespace,
  ["vimxl-motion:up"] = vim_translate.up,
  ["vimxl-motion:down"] = vim_translate.down,
  ["vimxl-motion:left"] = vim_translate.left,
  ["vimxl-motion:right"] = vim_translate.right,
  ["vimxl-motion:select-inner-word"] = vim_translate.inner_word,
  ["vimxl-motion:entire-current-line-or-more"] = vim_translate.entire_current_line_or_more,

  -- Normal and visual mode navigation.
  ["vimxl-motion:go-end-of-line"] = vim_translate.end_of_line,
  ["vimxl-motion:go-first-col"] = vim_translate.start_of_line,
  ["vimxl-motion:go-nth-col"] = vim_translate.nth_col,
  ["vimxl-motion:go-first-printable"] = vim_translate.first_printable,
  ["vimxl-motion:go-nth-line-printable"] = vim_translate.cursor_to_nth_line_printable,
  ["vimxl-motion:go-line-by-number"] = vim_translate.goto_line_by_number, -- Differs
  ["vimxl-motion:go-start-of-document"] = vim_translate.start_of_doc_or_line, -- Differs
  ["vimxl-motion:go-next-word"] = vim_translate.next_word_start_multiline, -- Differs
  ["vimxl-motion:go-next-word-by-whitespace"] = vim_translate.next_word_start_by_whitespace_multiline, -- Differs
  ["vimxl-motion:go-prev-word"] = vim_translate.prev_word_start,
  ["vimxl-motion:go-prev-word-by-whitespace"] = vim_translate.prev_word_start_by_whitespace,
  ["vimxl-motion:go-up"] = vim_translate.up,
  ["vimxl-motion:go-down"] = vim_translate.down,
  ["vimxl-motion:go-left"] = vim_translate.left,
  ["vimxl-motion:go-right"] = vim_translate.right,
}

return vim_motions
