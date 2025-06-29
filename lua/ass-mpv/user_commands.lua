---
---@class ass_mpv_user_commands
---@field register_commands fun(bufnr: integer): nil
---

local M = {}

local mpv = require("ass-mpv.mpv")

---
---Register user commands for a specific buffer
---@param bufnr integer Buffer number where commands should be registered
---
M.register_commands = function(bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, "AssMpvOpen", function(cmd_args)
        mpv.open_for_buf(bufnr, cmd_args.args)
    end, {
        desc = "Start ASS video session with MPV",
        nargs = "?",
        complete = "file",
    })

    vim.api.nvim_buf_create_user_command(bufnr, "AssMpvClose", function()
        mpv.quit_for_buf(bufnr)
    end, { desc = "Stop ASS video session with MPV" })

    vim.api.nvim_buf_create_user_command(bufnr, "AssMpvPause", function()
        mpv.pause_current()
    end, { desc = "Pause ASS video session with MPV" })
end

return M
