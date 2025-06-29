---
---Logger module for centralized logging
---

local Logger = {}

local fidget_ok, fidget = pcall(require, "fidget")

local log_levels = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
}

local current_level = log_levels.INFO -- Default log level
local log_file = nil

---
---Set the log level
---@param level string The log level: DEBUG, INFO, WARN, ERROR
---
function Logger.set_level(level)
    current_level = log_levels[level] or log_levels.INFO
end

---
---Enable verbose logging to a file
---@param path string The file path for logging
---
function Logger.enable_file_logging(path)
    log_file = path
end

---
---Internal function to log a message
---@param level string Log level of the message
---@param msg string The actual message to log
---@param notify boolean Whether to notify fidget.nvim
---
local function log(level, msg, notify)
    if log_levels[level] >= current_level then
        if notify then
            if fidget_ok then
                fidget.notify(msg, vim.log.levels[level])
            else
                vim.notify(msg, vim.log.levels[level])
            end
        end
        if log_file then
            local file = io.open(log_file, "a")
            if file then
                file:write(string.format("%s [%s] %s\n", os.date(), level, msg))
                file:close()
            end
        end
    end
end

---
---Log a debug message
---
function Logger.debug(msg, notify_fidget)
    log("DEBUG", msg, notify_fidget)
end

---
---Log an info message
---
function Logger.info(msg, notify_fidget)
    log("INFO", msg, notify_fidget)
end

---
---Log a warning message
---
function Logger.warn(msg, notify_fidget)
    log("WARN", msg, notify_fidget)
end

---
--- Log an error message
---
function Logger.error(msg, notify_fidget)
    log("ERROR", msg, notify_fidget)
end

return Logger
