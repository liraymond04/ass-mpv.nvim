local M = {}

local mpv = require("ass-mpv.mpv")

M.init_keymaps = function(bufnr, opts)
  local function set_keymap(key, desc, callback)
    if key then
      vim.keymap.set("n", key, callback, {
        buffer = bufnr,
        noremap = true,
        silent = true,
        desc = desc,
      })
    end
  end

  set_keymap(opts.keymaps.mpv_open, "Open MPV", function()
    vim.cmd("AssMpvOpen")
  end)

  set_keymap(opts.keymaps.mpv_close, "Quit MPV", function()
    mpv.quit_current()
  end)

  set_keymap(opts.keymaps.mpv_pause, "Pause MPV", function()
    mpv.pause_current()
  end)
end

return M
