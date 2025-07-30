---@type { [string]: string }
local vim_available_commands = {
  ["w"] = "doc:save",
  ["vs"] = "root:split-right",
  ["s"] = "root:split-down",
  ["qall"] = "core:quit",
  ["qall!"] = "core:force-quit",
  ["q"] = "root:close-or-quit",
  ["q!"] = "vimxl:force-close-or-quit",
}

---The commands that we want to be able to use from VimXL's command mode.
return vim_available_commands
