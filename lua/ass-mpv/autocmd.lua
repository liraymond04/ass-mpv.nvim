local M = {}
local user_commands = require("ass-mpv.user_commands")

local keymaps = require("ass-mpv.keymaps")
local mpv = require("ass-mpv.mpv")

M.setup_autocmds = function(opts)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "ass", "ssa" },
    callback = function(args)
      local bufnr = args.buf

      keymaps.init_keymaps(bufnr, opts)

      user_commands.register_commands(bufnr)

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
