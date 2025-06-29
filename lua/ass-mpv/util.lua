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

M.dump = function(o)
   if type(o) == 'table' then
      local s = '{ '
      for k, v in pairs(o) do
         local key = type(k) == 'number' and k or '"' .. tostring(k) .. '"'
         s = s .. '[' .. key .. '] = ' .. M.dump(v) .. ', '
      end
      return s .. '}'
   elseif type(o) == 'string' then
      return '"' .. o .. '"'
   else
      return tostring(o)
   end
end

---
--- Fallback logic for video path
--- @param ass_path string Path to the `.ass` file
--- @return string|nil Inferred video path or nil if not found
---
function M.fallback_video_path(ass_path)
    local base_dir = vim.fn.fnamemodify(ass_path, ":h")
    for _, ext in ipairs({ ".mp4", ".mkv", ".avi" }) do
        local video_path = base_dir .. "/" .. vim.fn.fnamemodify(ass_path, ":t:r") .. ext
        if vim.fn.filereadable(video_path) == 1 then
            return video_path
        end
    end
    return nil
end

return M
