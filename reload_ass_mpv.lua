-- Unload the plugin modules from package.loaded
for module, _ in pairs(package.loaded) do
    if module:match("^ass%-mpv") then
        package.loaded[module] = nil
    end
end

-- Re-require the main module and call setup
local ass_mpv = require("ass-mpv")
ass_mpv.setup()

-- Save the current buffer and window
local current_buf = vim.api.nvim_get_current_buf()
local current_win = vim.api.nvim_get_current_win()

-- Close and reopen buffers with filetype "ass" or "ssa" in the background
for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
        local filetype = vim.bo[bufnr].filetype
        if filetype == "ass" or filetype == "ssa" then
            -- Save the buffer's state
            local filename = vim.api.nvim_buf_get_name(bufnr)
            local is_modified = vim.bo[bufnr].modified
            local buf_content = is_modified and vim.api.nvim_buf_get_lines(bufnr, 0, -1, true) or nil
            local cursor_pos = vim.api.nvim_win_get_cursor(0)
            local view = vim.fn.winsaveview()

            -- Close the buffer silently
            vim.cmd("silent! bwipeout " .. bufnr)

            -- Reopen the buffer silently
            vim.cmd("silent! edit " .. vim.fn.fnameescape(filename))

            -- Restore buffer content if it was modified
            if is_modified and buf_content then
                vim.api.nvim_buf_set_lines(0, 0, -1, true, buf_content)
                vim.bo.modified = true
            end

            -- Restore cursor position and view
            vim.api.nvim_win_set_cursor(0, cursor_pos)
            vim.fn.winrestview(view)
        end
    end
end

-- Restore the original buffer and window
vim.api.nvim_set_current_win(current_win)
vim.api.nvim_set_current_buf(current_buf)

print("ass-mpv.nvim plugin reloaded and setup restarted.")
