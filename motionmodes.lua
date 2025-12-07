--When set selection will be clamped
--to include every line that it passes. Including the newline character.
--Mutually exclusive with CHARWISE.
-- TODO: for perfect emulation there should also be a way to set exclusive or inclusive modes (of line mode).
local MOTION_MODE_LINEWISE = {
  is_linewise = true,
  is_charwise = false,
  is_text_object = false,
}

local MOTION_MODE_CHARWISE = {
  is_linewise = false,
  is_charwise = true,
  is_text_object = false,
}

local MOTION_MODE_CHARWISE_TEXT_OBJECT = {
  is_linewise = false,
  is_charwise = true,
  is_text_object = true,
}

local MOTION_MODE_LINEWISE_TEXT_OBJECT = {
  is_linewise = true,
  is_charwise = false,
  is_text_object = true,
}

---@alias vimxl.motion_mode {is_linewise: boolean, is_charwise: boolean, is_text_object: boolean}

--A collection of bitmasks that define how different motions and text objects should be treated.
--@type { [string]: vimxl.motion_mode }
local vim_motion_modes = {
  ["vimxl-motion:line-by-number"] = MOTION_MODE_LINEWISE,
  ["vimxl-motion:start-of-document"] = MOTION_MODE_LINEWISE,
  ["vimxl-motion:up"] = MOTION_MODE_LINEWISE,
  ["vimxl-motion:down"] = MOTION_MODE_LINEWISE,
  ["vimxl-motion:nth-line-minus-one-printable"] = MOTION_MODE_LINEWISE,
  ["vimxl-motion:nth-line-printable"] = MOTION_MODE_LINEWISE,
  ["vimxl-motion:end-or-line-no"] = MOTION_MODE_LINEWISE,

  ["vimxl-motion:entire-current-line-or-more"] = MOTION_MODE_CHARWISE_TEXT_OBJECT,
  ["vimxl-motion:select-inner-word"] = MOTION_MODE_CHARWISE_TEXT_OBJECT,
  ["vimxl-motion:select-in-paragraph"] = MOTION_MODE_LINEWISE_TEXT_OBJECT,
}

return {
  motion_modes = vim_motion_modes,
  MOTION_MODE_CHARWISE = MOTION_MODE_CHARWISE,
  MOTION_MODE_LINEWISE = MOTION_MODE_LINEWISE,
  MOTION_MODE_CHARWISE_TEXT_OBJECT = MOTION_MODE_CHARWISE_TEXT_OBJECT,
}
