local M = {}

local autocmds = require("ass-mpv.autocmd")
local main_key = "<leader>m"

M.setup = function(opts)
    opts = opts or {}
    opts.use_main_key = opts.use_main_key or true
    opts.main_key = opts.main_key or main_key
    opts.keymaps = opts.keymaps
        or {
            mpv_open = opts.main_key .. "o",
            mpv_close = opts.main_key .. "q",
            mpv_pause = opts.main_key .. "p",
        }

    -- Setup autocommands using the extracted module
    autocmds.setup_autocmds(opts)
end

return M
