local M = {}

local mpv = require("ass-mpv.mpv")

local main_key = "m"

M.setup = function(opts)
    opts = opts or {}

    vim.api.nvim_create_autocmd("FileType", {
        pattern = { "ass", "ssa" },
        callback = function(args)
            local bufnr = args.buf

            -- buffer-local keymaps:
            vim.keymap.set(
                "n",
                "<leader>" .. main_key .. "q",
                function()
                    mpv.quit_current()
                end,
                {
                    buffer = bufnr,
                    noremap = true,
                    silent = true,
                    desc = "Quit MPV",
                }
            )

            -- buffer-local user commands
            vim.api.nvim_buf_create_user_command(
                bufnr,
                "AssMpvOpen",
                function(cmd_args)
                    mpv.open_for_buf(bufnr, cmd_args.args)
                end,
                {
                    desc = "Start ASS video session with MPV",
                    nargs = "?",
                    complete = "file",
                }
            )
            vim.api.nvim_buf_create_user_command(
                bufnr,
                "AssMpvClose",
                function()
                    mpv.quit_for_buf(bufnr)
                end,
                { desc = "Stop ASS video session with MPV" }
            )

            vim.api.nvim_buf_create_user_command(
                bufnr,
                "AssMpvPause",
                function()
                    mpv.pause_current()
                end,
                { desc = "Pause ASS video session with MPV" }
            )

            -- auto-cleanup on buffer delete
            vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
                buffer = bufnr,
                callback = function()
                    mpv.quit_for_buf(bufnr)
                end,
            })
        end,
    })
end

return M
