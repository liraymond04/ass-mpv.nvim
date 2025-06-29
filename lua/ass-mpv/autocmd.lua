---
---@class ass_mpv_autocmd
---@field setup_autocmds fun(opts: table): nil
---

local M = {}
local user_commands = require("ass-mpv.user_commands")

local aegisub = require("ass-mpv.aegisub")
local keymaps = require("ass-mpv.keymaps")
local mpv = require("ass-mpv.mpv")

---
---Setup autocommands for the plugin
---@param opts PluginOptions Options for configuring the autocommands
---
M.setup_autocmds = function(opts)
    vim.api.nvim_create_autocmd("FileType", {
        pattern = { "ass", "ssa" },
        callback = function(args)
            local bufnr = args.buf

            keymaps.init_keymaps(bufnr, opts)

            user_commands.register_commands(bufnr)

            -- handle project metadata
            local target = vim.api.nvim_buf_get_name(bufnr)
            local sections, _ = require("ass-mpv.aegisub").parse_ass(target)
            local metadata = aegisub.read_metadata(sections["Script Info"])
            if not next(metadata) then
                aegisub.write_metadata(target, {
                    name = "Default Project",
                    version = "1.0",
                    authors = {},
                })
            end

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
