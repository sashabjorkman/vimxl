-- Which motions should be treated as linewise?
-- Which is to say that the selection will be clamped
-- to include every line that it passes. Including the
-- newline character.
-- TODO: for perfect emulation there should also be a way to set exclusive or inclusive modes.
local vim_linewise = {
  ["vimxl-motion:line-by-number"] = true,
  ["vimxl-motion:start-of-document"] = true,
  ["vimxl-motion:up"] = true,
  ["vimxl-motion:down"] = true,
  ["vimxl-motion:nth-line-minus-one-printable"] = true,
  ["vimxl-motion:nth-line-printable"] = true,
}

return vim_linewise
