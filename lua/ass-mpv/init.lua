---
---@class ass_mpv
---@field setup fun(opts: PluginOptions?): nil
---
local M = {}

---@class PluginKeymaps
---@field mpv_open string? Keymap to open MPV
---@field mpv_close string? Keymap to quit MPV
---@field mpv_pause string? Keymap to pause MPV
---
---@class PluginOptions
---@field use_main_key boolean? Whether to use the default main key
---@field main_key string? The main key for the plugin (e.g., <leader>m)
---@field keymaps PluginKeymaps? Table of keymap options
---

local autocmds = require("ass-mpv.autocmd")
local main_key = "<leader>m"

---
---Setup the ass-mpv plugin
---@param opts PluginOptions Options for configuring the plugin
---
M.setup = function(opts)
    local defaults = {
        use_main_key = true,
        main_key = main_key,
        keymaps = {
            mpv_open = main_key .. "o",
            mpv_close = main_key .. "q",
            mpv_pause = main_key .. "p",
        },
    }

    -- Define metatable for runtime validation and default value setup
    local opts_mt = {
        __index = function(_, key)
            if defaults[key] ~= nil then
                return defaults[key]
            else
                error("Missing required option: " .. key)
            end
        end,
    }

    -- Apply the metatable to opts and validate
    opts = setmetatable(opts or {}, opts_mt)

    -- Validate keymaps structure
    if type(opts.keymaps) ~= "table" then
        error("'keymaps' must be a table.")
    end

    local missing_keys = {}
    for key, _ in pairs(defaults.keymaps) do
        if not opts.keymaps[key] then
            table.insert(missing_keys, key)
        end
    end

    if #missing_keys > 0 then
        error("Invalid 'keymaps' table. Missing required keys: " .. table.concat(missing_keys, ", "))
    end

    autocmds.setup_autocmds(opts)
end

return M
