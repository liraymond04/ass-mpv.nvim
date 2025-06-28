local M = {}

local autocmds = require("ass-mpv.autocmd")
local main_key = "<leader>m"

M.setup = function(opts)
    opts = opts or {}
    opts.keymaps = opts.keymaps or {}
    opts.main_key = opts.main_key or main_key
    opts.use_main_key = opts.use_main_key or true

    -- Setup autocommands using the extracted module
    autocmds.setup_autocmds(opts)
end

return M
