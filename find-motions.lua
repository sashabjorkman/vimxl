local vim_motions = require "plugins.vimxl.motions"
local constants = require "plugins.vimxl.constants"

---@type { [string]: string }
local find_character_motions = {}

---@type { [string]: string }
local find_character_motions_reverse = {}

---@type { [string]: string }
local navigate_find_character = {}

---@type { [string]: string }
local navigate_find_character_reverse = {}

for c in constants.PRINTABLE_CHARACTERS:gmatch"." do
  vim_motions["vimxlmotion:find_"..c] = function (doc, line, col, _, count)
    if count == nil then count = 1 end
    for i = col, #doc.lines[line] do
      if doc:get_char(line, i) == c then
        if count > 1 then
          count = count - 1
        else
          return line, col, line, i + 1
        end
      end
    end
    return line, col, line, col
  end
  find_character_motions[c] = "vimxlmotion:find_"..c

  vim_motions["vimxlmotion:go_find_"..c] = function (doc, line, col, _, count)
      if count == nil then count = 1 end
      for i = col + 1, #doc.lines[line] do
        if doc:get_char(line, i) == c then
          if count > 1 then
            count = count - 1
          else
            return line, i
          end
        end
      end
      return line, col
  end
  navigate_find_character[c] = "vimxlmotion:go_find_"..c

  vim_motions["vimxlmotion:reverse_find_"..c] = function (doc, line, col, _, count)
    if count == nil then count = 1 end
    for i = col, 1, -1 do
      if doc:get_char(line, i) == c then
        if count > 1 then
          count = count - 1
        else
          return line, i, line, col
        end
      end
    end
    return line, col, line, col
  end
  find_character_motions_reverse[c] = "vimxlmotion:reverse_find_"..c

  vim_motions["vimxlmotion:go_reverse_find_"..c] = function (doc, line, col, _ ,count)
    if count == nil then count = 1 end
    for i = col - 1, 1, -1 do
      if doc:get_char(line, i) == c then
        if count > 1 then
          count = count - 1
        else
          return line, i
        end
      end
    end
    return line, col
  end
  navigate_find_character_reverse[c] = "vimxlmotion:go_reverse_find_"..c
end

---A collection of motions implementing f and F for both motion
---as arguments and motions for ordinary navigation.
return {
  ["forward"] = find_character_motions,
  ["backward"] = find_character_motions_reverse,
  ["navigate_forward"] = navigate_find_character,
  ["navigate_backward"] = navigate_find_character_reverse,
}
