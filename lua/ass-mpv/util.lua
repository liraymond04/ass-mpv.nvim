local M = {}

M.is_command_available = function(command)
    local result = vim.fn.system("command -v " .. command)
    return vim.fn.empty(result) == 0 -- returns true if command is found
end

return M
