---@type { [string]: string }
local vim_available_commands = {
  ["w"] = "doc:save",
  ["vs"] = "root:split-right",
  ["s"] = "root:split-down",
  ["qall"] = "core:quit",
  ["qall!"] = "core:force-quit",
  ["q"] = "vimxl:close-or-quit",
  ["q!"] = "vimxl:force-close-or-quit",
  ["bd"] = "vimxl:kill-view",
}

---The commands that we want to be able to use from VimXL's command mode.
return vim_available_commands
