-- Default keymap for Vim-mode. Note that the
-- keymap for Vim-mode does not build upon the Lite-XL keymap.

local keymap = require "core.keymap"

local constants = require "plugins.vimxl.constants"
local find_motions = require "plugins.vimxl.find-motions"

---Normally used as a key inside of keymaps.
---It suppports numbers because that is how we encode special cases 
---like repeat motion names (yy) or a leading zero.
---@alias vimxl.lookup_name string|number
---
---@alias vimxl.keybind_map { [vimxl.lookup_name]: vimxl.keybind_value }
---@alias vimxl.keybind_value string|vimxl.keybind_map

-- Navigation motions (in normal and visual) and operation motions behave differnetly enough that there is no point in trying to unify the code for them.
local motions = {
  ["$"] = "vimxlmotion:end_of_line",
  [constants.LEADING_ZERO] = "vimxlmotion:first_col",
  ["|"] = "vimxlmotion:nth_col",
  ["^"] = "vimxlmotion:first_printable",
  ["_"] = "vimxlmotion:nth_line_printable",
  ["G"] = "vimxlmotion:line_by_number",
  ["g"] = {
    ["g"] = "vimxlmotion:start_of_document",
  },
  ["w"] = "vimxlmotion:next_word",
  ["W"] = "vimxlmotion:next_word_by_whitespace",
  ["b"] = "vimxlmotion:prev_word",
  ["B"] = "vimxlmotion:prev_word_by_whitespace",
  ["k"] = "vimxlmotion:up",
  ["j"] = "vimxlmotion:down",
  ["h"] = "vimxlmotion:left",
  ["l"] = "vimxlmotion:right",
  ["f"] = find_motions.forward,
  ["F"] = find_motions.backward,
  ["i"] = {
    ["w"] = "vimxlmotion:select_inner_word",
  },
  [constants.MOTION_LINE_REPEAT] = "vimxlmotion:entire_current_line_or_more",
}

---@type vimxl.keybind_map
local normal_and_visual_mode = {
  ["$"] = "vimxlmotion:go_end_of_line",
  [constants.LEADING_ZERO] = "vimxlmotion:go_first_col",
  ["|"] = "vimxlmotion:go_nth_col",
  ["^"] = "vimxlmotion:go_first_printable",
  ["_"] = "vimxlmotion:go_nth_line_printable",
  ["G"] = "vimxlmotion:go_line_by_number",
  ["g"] = {
    ["g"] = "vimxlmotion:go_start_of_document",
  },
  ["w"] = "vimxlmotion:go_next_word",
  ["W"] = "vimxlmotion:go_next_word_by_whitespace",
  ["b"] = "vimxlmotion:go_prev_word",
  ["B"] = "vimxlmotion:go_prev_word_by_whitespace",
  ["k"] = "vimxlmotion:go_up",
  ["j"] = "vimxlmotion:go_down",
  ["h"] = "vimxlmotion:go_left",
  ["l"] = "vimxlmotion:go_right",
  ["f"] = find_motions.navigate_forward,
  ["F"] = find_motions.navigate_backward,
}

---@type vimxl.keybind_map
local visual_mode = {
  ["y"] = "v_yank",
  ["s"] = "v_substitute",
  ["c"] = "v_change",
  ["d"] = "v_delete",
}

---@type vimxl.keybind_map
local normal_mode = {
  ["v"] = "visual_mode",
  ["i"] = "insert_mode",
  ["u"] = "undo",
  ["I"] = "append_to_start",
  ["A"] = "append_to_end",
  ["o"] = "newline_below",
  ["O"] = "newline_above",
  ["d"] = "delete",
  ["c"] = "change",
  ["y"] = "yank",
  ["P"] = "paste_before",
  ["p"] = "paste_after",
  ["/"] = "find",
  ["n"] = "repeat_find",
  ["N"] = "previous_find",
  ["."] = "repeat",
  [":"] = "command_mode",
}

for k, v in pairs(normal_and_visual_mode) do
  normal_mode[k] = v
  visual_mode[k] = v
end

-- Applies globally. This uses the Lite-XL keymap because the Vim-mode keymap
-- is only concerned with data that is given through on_text_input.
keymap.add {
  ["escape"] = { "vimxl:escape-mode" },
  ["left"] = { "vimxl:move-to-previous-char" },
  ["right"] = { "vimxl:move-to-next-char" },
  ["up"] = { "vimxl:move-to-previous-line" },
  ["down"] = { "vimxl:move-to-next-line" },
  ["pageup"] = { "vimxl:move-to-previous-page" },
  ["pagedown"] = { "vimxl:move-to-next-page" },
  ["ctrl+r"] = { "vimxl:undo" },
}

---A collection of different keymap roots.
return {
  ["motions"] = motions,
  ["normal"] = normal_mode,
  ["visual"] = visual_mode,
}
