---
---@class ass_mpv_util
---@field is_command_available fun(command: string): boolean
---

local M = {}

---
---Check if a shell command is available
---@param command string The command to check
---@return boolean True if the command exists, false otherwise
---
M.is_command_available = function(command)
    local result = vim.fn.system("command -v " .. command)
    return vim.fn.empty(result) == 0 -- returns true if command is found
end

return M
