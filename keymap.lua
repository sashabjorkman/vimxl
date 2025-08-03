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
  ["$"] = "vimxl-motion:end-of-line",
  [constants.LEADING_ZERO] = "vimxl-motion:first-col",
  ["|"] = "vimxl-motion:nth-col",
  ["^"] = "vimxl-motion:first-printable",
  ["_"] = "vimxl-motion:nth-line-minus-one-printable",
  ["+"] = "vimxl-motion:nth-line-printable",
  ["\n"] = "vimxl-motion:nth-line-printable",
  ["G"] = "vimxl-motion:end-or-line-no",
  ["g"] = {
    ["g"] = "vimxl-motion:start-of-document",
  },
  ["w"] = "vimxl-motion:next-word",
  ["W"] = "vimxl-motion:next-word-by-whitespace",
  ["b"] = "vimxl-motion:prev-word",
  ["B"] = "vimxl-motion:prev-word-by-whitespace",
  ["k"] = "vimxl-motion:up",
  ["j"] = "vimxl-motion:down",
  ["h"] = "vimxl-motion:left",
  ["l"] = "vimxl-motion:right",
  ["f"] = find_motions.forward,
  ["F"] = find_motions.backward,
  ["i"] = {
    ["w"] = "vimxl-motion:select-inner-word",
  },
  [constants.MOTION_LINE_REPEAT] = "vimxl-motion:nth-line-minus-one-printable",

  -- TODO: Add "v" that disables linewise for the operation. This would require some special logic in vimstate.
}

---@type vimxl.keybind_map
local normal_and_visual_mode = {
  ["$"] = "vimxl-motion:end-of-line",
  [constants.LEADING_ZERO] = "vimxl-motion:first-col",
  ["|"] = "vimxl-motion:nth-col",
  ["^"] = "vimxl-motion:first-printable",
  ["_"] = "vimxl-motion:nth-line-minus-one-printable",
  ["+"] = "vimxl-motion:nth-line-printable",
  ["\n"] = "vimxl-motion:nth-line-printable",
  ["G"] = "vimxl-motion:end-or-line-no",
  ["g"] = {
    ["g"] = "vimxl-motion:start-of-document",
  },
  ["w"] = "vimxl-motion:next-word-multiline",
  ["W"] = "vimxl-motion:next-word-by-whitespace-multiline",
  ["b"] = "vimxl-motion:prev-word",
  ["B"] = "vimxl-motion:prev-word-by-whitespace",
  ["k"] = "vimxl-motion:up",
  ["j"] = "vimxl-motion:down",
  ["h"] = "vimxl-motion:left",
  ["l"] = "vimxl-motion:right-clamped",
  ["f"] = find_motions.navigate_forward,
  ["F"] = find_motions.navigate_backward,
}

---@type vimxl.keybind_map
local visual_common_mode = {
  ["y"] = "vimxl-visual:yank",
  ["s"] = "vimxl-visual:substitute",
  ["c"] = "vimxl-visual:change",
  ["d"] = "vimxl-visual:delete",
  ["p"] = "vimxl-visual:paste",
  ["P"] = "vimxl-visual:paste",
  ["i"] = {
    ["w"] = "vimxl-motion:select-inner-word",
  },
}

---@type vimxl.keybind_map
local visual_mode = {
  ["v"] = "vimxl-visual:normal-mode",
  [">"] = "vimxl-visual:indent",
  ["<"] = "vimxl-visual:unindent",
}

---@type vimxl.keybind_map
local visual_block_mode = {
  [constants.CTRL_V] = "vimxl-visual:normal-mode",
  ["I"] = "vimxl-visual-block:append-to-start",
  -- TODO: Implement blockwise for them:
  --[">"] = "vimxl-visual-block:indent",
  --["<"] = "vimxl-visual-block:unindent",
}

---@type vimxl.keybind_map
local visual_line_mode = {
  ["V"] = "vimxl-visual:normal-mode",
  -- TODO: If we have moved up then I should enter at the cursor, if we have moved down then it should enter I mode at the start of the selection, very strange.
  --["I"] = "",
  [">"] = "vimxl-visual:indent",
  ["<"] = "vimxl-visual:unindent",
}


---@type vimxl.keybind_map
local normal_mode = {
  ["v"] = "vimxl-normal:visual-mode",
  ["V"] = "vimxl-normal:visual-line-mode",
  [constants.CTRL_V] = "vimxl-normal:visual-block-mode",
  ["i"] = "vimxl-normal:insert-mode",
  ["u"] = "vimxl-normal:undo",
  ["I"] = "vimxl-normal:append-to-start",
  ["A"] = "vimxl-normal:append-to-end",
  ["o"] = "vimxl-normal:newline-below",
  ["O"] = "vimxl-normal:newline-above",
  ["d"] = "vimxl-normal:delete",
  ["c"] = "vimxl-normal:change",
  ["y"] = "vimxl-normal:yank",
  ["P"] = "vimxl-normal:paste-before",
  ["p"] = "vimxl-normal:paste-after",
  [">"] = "vimxl-normal:indent",
  ["<"] = "vimxl-normal:unindent",
  ["/"] = "vimxl-normal:find",
  ["n"] = "vimxl-normal:repeat-find",
  ["N"] = "vimxl-normal:previous-find",
  ["."] = "vimxl-normal:repeat",
  [":"] = "vimxl-normal:command-mode",
}

for k, v in pairs(normal_and_visual_mode) do
  normal_mode[k] = v
  visual_mode[k] = v
  visual_block_mode[k] = v
  visual_line_mode[k] = v
end

for k, v in pairs(visual_common_mode) do
  visual_mode[k] = v
  visual_line_mode[k] = v
  visual_block_mode[k] = v
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
  ["ctrl+r"] = { "vimxl:redo" },
  ["ctrl+v"] = { "vimxl:enter-block-mode" },
  ["return"] = { "vimxl:newline" },
  ["keypad enter"] = { "vimxl:newline" },
}

---A collection of different keymap roots.
return {
  ["motions"] = motions,
  ["normal"] = normal_mode,
  ["visual"] = visual_mode,
  ["visual_block"] = visual_block_mode,
  ["visual_line"] = visual_line_mode,
}
