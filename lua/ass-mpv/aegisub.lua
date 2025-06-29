local M = {}

local logger = require("ass-mpv.logger")
local util = require("ass-mpv.util")

---
---Parse an `.ass` file into structured Lua tables
---@param file_path string Path to the ASS file
---@return table<string, table>, table<string> Parsed sections of the ASS file and section order
---
function M.parse_ass(file_path)
    local sections = {}
    local current_section
    local section_order = {}
    local line_num = 0

    for line in io.lines(file_path) do
        line_num = line_num + 1
        line = line:match("^%s*(.-)%s*$") -- Trim whitespace
        if line:match("^%[.+%]$") then
            -- Start of a new section
            current_section = line:match("^%[(.+)%]$")
            sections[current_section] = { lines = {}, start_line = line_num }
            table.insert(section_order, current_section)
        elseif current_section and line ~= "" then
            -- Add content to the current section
            table.insert(sections[current_section].lines, line)
        elseif line == "" and current_section then
            -- Treat empty lines as section delimiters
            current_section = nil
        end
    end

    return sections, section_order
end

---
---Serialize Lua table back into ASS file format
---@param sections table<string, table> Parsed sections
---@return string Serialized ASS content
---
function M.serialize_ass(sections, section_order)
    local result = {}
    for _, section in ipairs(section_order) do
        local content = sections[section]
        table.insert(result, ("[%s]"):format(section))
        for _, line in ipairs(content.lines) do
            table.insert(result, line)
        end
    end
    return table.concat(result, "\n")
end

---
---Read metadata from the `Title` field in `[Script Info]`
---@param script_info table The `[Script Info]` table
---@return table Deserialized Lua table containing metadata
---
function M.read_metadata(script_info)
    for _, line in ipairs(script_info.lines) do
        if line:match("^Title:") then
            local title = line:match("^Title:%s*(.+)$")
            local func, err = loadstring("return " .. title)
            if func then
                local ok, metadata = pcall(func)
                if ok then
                    if type(metadata) == "table" then
                        return metadata
                    else
                        logger.warn("Invalid Lua object in Title: Not a table", true)
                    end
                else
                    logger.warn("Error executing Lua object in Title: " .. metadata, true)
                end
            else
                logger.warn("Invalid Lua object in Title: " .. err, true)
            end
            return {}
        end
    end
    return {}
end

---
---Write metadata into the `Title` field in `[Script Info]`
---@param file_path string Path to the ASS file
---@param metadata table Metadata to write into the buffer
---@return nil
---
function M.write_metadata(file_path, metadata)
    local bufnr = vim.fn.bufnr(file_path, true) -- Get or create the buffer for the file
    local serialized = ("Title: %s"):format(util.dump(metadata))

    -- Iterate over each line in the buffer
    for i = 1, vim.api.nvim_buf_line_count(bufnr) do
        local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
        if line:match("^Title:") then
            vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { serialized })
            break
        end
    end
end

return M
