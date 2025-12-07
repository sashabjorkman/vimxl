local vim_translate = require "plugins.vimxl.translate"

---A Vim motion that can be used either by a vim_command calling expect_motion,
---Or directly by putting it into a keymap, in which case it will either move
---or select depending on the current mode.
---Keep in mind that this is a bit of an unfortunate name as text objects
---also have this type.
---@alias vimxl.motion fun(doc: core.doc, line: number, col: number, view: core.docview, numerical_argument: number | nil): number, number, number | nil, number | nil

---Contains all known Vim motions.
---This is the only place where motions can be placed.
---If they are placed outside of this table then they will
---not be treated as such.
---
---@type { [string]: vimxl.motion }
local vim_motions = {

  -- Vim motions.
  ["vimxl-motion:end-of-line"] = vim_translate.end_of_line,
  ["vimxl-motion:first-col"] = vim_translate.start_of_line,
  ["vimxl-motion:nth-col"] = vim_translate.nth_col,
  ["vimxl-motion:first-printable"] = vim_translate.first_printable,
  ["vimxl-motion:nth-line-minus-one-printable"] = vim_translate.nth_line_minus_one_printable,
  ["vimxl-motion:nth-line-printable"] = vim_translate.nth_line_printable,
  ["vimxl-motion:end-or-line-no"] = vim_translate.end_of_doc_or_line_number,
  ["vimxl-motion:start-of-document"] = vim_translate.start_of_doc_or_line_number,
  ["vimxl-motion:prev-word"] = vim_translate.prev_word_start,
  ["vimxl-motion:prev-word-by-whitespace"] = vim_translate.prev_word_start_by_whitespace,
  ["vimxl-motion:up"] = vim_translate.up,
  ["vimxl-motion:down"] = vim_translate.down,
  ["vimxl-motion:left"] = vim_translate.left,
  ["vimxl-motion:right"] = vim_translate.right,
  ["vimxl-motion:right-clamped"] = vim_translate.right_clamped,

  -- Given distinct ID:s so that the others don't have to be treated as linewise. They use the same underlying function.
  ["vimxl-motion:linewise-up"] = vim_translate.up,
  ["vimxl-motion:linewise-down"] = vim_translate.down,

  -- Operator motion specifics.
  ["vimxl-motion:select-inner-word"] = vim_translate.inner_word,
  ["vimxl-motion:select-in-paragraph"] = vim_translate.in_paragraph,
  ["vimxl-motion:select-around-paragraph"] = vim_translate.around_paragraph,
  ["vimxl-motion:entire-current-line-or-more"] = vim_translate.entire_current_line_or_more,
  ["vimxl-motion:next-word"] = vim_translate.next_word_start,
  ["vimxl-motion:next-word-by-whitespace"] = vim_translate.next_word_start_by_whitespace,
  ["vimxl-motion:end-of-word"] = vim_translate.end_of_word,

  -- Normal and visual mode specifics.
  ["vimxl-motion:next-word-multiline"] = vim_translate.next_word_start_multiline,
  ["vimxl-motion:next-word-by-whitespace-multiline"] = vim_translate.next_word_start_by_whitespace_multiline,
}

return vim_motions
