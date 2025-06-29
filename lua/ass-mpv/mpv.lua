local uv = vim.uv
local fn = vim.fn
local api = vim.api
---
---@class MPVSession
---@field job_id integer The ID of the running MPV job
---@field socket string Path to the IPC socket
---@field ipc uv.uv_pipe_t|nil The IPC pipe for communication
---@field listeners table<string, function[]> Registered event listeners
---@field watcher uv.uv_timer_t|nil Timer to watch for socket activity
---@field reader uv.uv_pipe_t|nil Reader pipe for IPC communication
---
---@class MPV
---A module to interact with MPV via IPC.
---@field sessions table<integer, MPVSession> Tracks active MPV sessions (keyed by buffer number)
---

local M = {}

local aegisub = require("ass-mpv.aegisub")
local logger = require("ass-mpv.logger")
local util = require("ass-mpv.util")

if not util.is_command_available("mpv") then
    logger.error("Error: 'mpv' is not installed", true)
    return
end
if not util.is_command_available("socat") then
    logger.error("Error: 'socat' is not installed", true)
    return
end

---Track sessions: bufnr -> { job_id = ..., socket = ... }
M.sessions = {}

---
---Helper to build a per-buffer socket path.
---@param bufnr integer The buffer number.
---@return string The socket path.
---
local socket_path_for = function(bufnr)
    return string.format("/tmp/ass_nvim_mpv_%d.sock", bufnr)
end

---
---Helper to check if a job is still running.
---@param job_id integer The job ID to check.
---@return boolean True if the job is still running, false otherwise.
---
local is_job_running = function(job_id)
    local status = vim.fn.jobwait({ job_id }, 0)[1]
    -- jobwait returns:
    --   -1 if still running
    --   ≥0 exit code if it exited
    return status == -1
end

---
---Send a JSON-RPC command to MPV via the IPC socket.
---@param sock string The path to the IPC socket.
---@param payload table The JSON-RPC payload to send.
---
local send_ipc = function(sock, payload)
    local json = fn.json_encode(payload)
    -- echo '{"command": [...]}' | socat - UNIX-CONNECT:/path/to.sock
    local cmd = string.format("echo %q | socat - UNIX-CONNECT:%s", json, sock)
    fn.system(cmd)
end

---
---Send a JSON-RPC command to MPV via an IPC socket connected in a buffer.
---@param bufnr integer The buffer number with the IPC socket connection.
---@param payload table The JSON-RPC payload to send.
---
local send_ipc_buf = function(bufnr, payload)
    local sess = M.sessions[bufnr]
    if not sess or not sess.ipc then
        vim.schedule(function()
            logger.error("No IPC pipe to write to for buffer " .. bufnr)
        end)
        return
    end

    local json = vim.fn.json_encode(payload) .. "\n"
    -- write is non-blocking; you can optionally pass a callback(err)
    sess.ipc:write(json, function(write_err)
        if write_err then
            vim.schedule(function()
                logger.error("Failed to send IPC command: " .. write_err)
            end)
        end
    end)
end

---
---Observe an MPV property on the IPC socket connected to a buffer.
---@param bufnr integer The buffer number with the connected IPC socket.
---@param request_id integer The unique request ID for the observation.
---@param prop string The MPV property to observe.
---
local observe_property = function(bufnr, request_id, prop)
    local payload = { command = { "observe_property", request_id, prop } }
    send_ipc_buf(bufnr, payload)
end

---
---Internal handler for dispatching MPV events to registered listeners.
---@param bufnr integer The buffer number.
---@param msg table The event message from MPV.
---
M._handle_event = function(bufnr, msg)
    local ls = M.sessions[bufnr] and M.sessions[bufnr].listeners
    if not ls then
        return
    end

    if msg.event == "property-change" then
        local handlers = ls[msg.name]
        if handlers then
            for _, cb in ipairs(handlers) do
                vim.schedule_wrap(cb)(msg.data)
            end
        end
    elseif msg.event then
        -- generic event handlers under name = event
        local handlers = ls[msg.event]
        if handlers then
            for _, cb in ipairs(handlers) do
                vim.schedule_wrap(cb)(msg)
            end
        end
    end
end

---
--- Start reading MPV's IPC socket for JSON events and EOF.
--- @param bufnr integer The buffer number.
---
M._start_event_reader = function(bufnr)
    local sess = M.sessions[bufnr]
    if not sess then
        return
    end

    local ipc = uv.new_pipe(false)
    sess.ipc = ipc

    if not ipc then
        logger.error("Failed to create new pipe for buffer: " .. bufnr)
        return
    end

    ipc:connect(sess.socket, function(connection_err)
        if connection_err then
            vim.schedule(function()
                logger.error("IPC connect error: " .. connection_err, true)
            end)
            return
        end

        ipc:read_start(function(err, chunk)
            if err then
                vim.schedule(function()
                    logger.error("IPC read error: " .. err, true)
                end)
                return
            end

            if not chunk then
                -- EOF: MPV quit or crashed
                vim.schedule(function()
                    M._cleanup(bufnr)
                    logger.warn("MPV session ended", true)
                end)

                -- Attempt to reconnect to MPV
                local _sess = M.sessions[bufnr]
                if _sess then
                    vim.defer_fn(function()
                        -- TODO handle real reconnect later
                        -- M.reconnect(bufnr)
                    end, 500) -- Retry after 500ms
                end

                return
            end

            -- parse one or more JSON lines
            for line in chunk:gmatch("[^\r\n]+") do
                vim.schedule(function()
                    local ok, msg = pcall(fn.json_decode, line)
                    if ok and msg then
                        M._handle_event(bufnr, msg)
                    end
                end)
            end
        end)
    end)
end

---
---Safely clean up a buffer's MPV session.
---Stops the reader pipe, watcher, and the MPV process, and removes the socket file.
---@param bufnr integer The buffer number.
---
M._cleanup = function(bufnr)
    local sess = M.sessions[bufnr]
    if not sess then
        return
    end

    -- stop & close the UV reader pipe
    if sess.reader then
        sess.reader:read_stop()
        if not uv.is_closing(sess.reader) then
            sess.reader:close()
        end
        sess.reader = nil
    end

    -- stop & close any socket-watcher timer
    if sess.watcher then
        sess.watcher:stop()
        if not uv.is_closing(sess.watcher) then
            sess.watcher:close()
        end
        sess.watcher = nil
    end

    -- kill the job if still alive
    vim.fn.jobstop(sess.job_id)

    -- remove the socket file
    os.remove(sess.socket)

    -- finally drop our record
    M.sessions[bufnr] = nil
end

---
---Wait for a UNIX socket to appear, then call a callback function.
---@param path string The path to the UNIX socket.
---@param timeout number The maximum time (in milliseconds) to wait.
---@param interval number The interval (in milliseconds) between checks.
---@param cb function The callback function to invoke when the socket appears.
---
local wait_for_socket = function(path, timeout, interval, cb)
    local elapsed = 0
    local timer = uv.new_timer()

    if not timer then
        return
    end

    timer:start(
        0,
        interval,
        vim.schedule_wrap(function()
            local stat = uv.fs_stat(path)
            if stat and stat.type == "socket" then
                timer:stop()
                timer:close()
                cb()
            else
                elapsed = elapsed + interval
                if elapsed >= timeout then
                    timer:stop()
                    timer:close()
                    vim.schedule(function()
                        logger.error(("Timed out (%dms) waiting for MPV socket at %s"):format(timeout, path), true)
                    end)
                end
            end
        end)
    )
end

---
--- Start MPV for a specific buffer.
--- If MPV is already running for the buffer, logs a notification instead.
--- @param bufnr integer The buffer number.
--- @param file string|nil The override path to play. Defaults to the current buffer's file.
---
M.open_for_buf = function(bufnr, file)
    if M.sessions[bufnr] then
        logger.info("MPV is already running for this buffer", true)
        return
    end

    -- Determine what to play
    local target = file or api.nvim_buf_get_name(bufnr)
    if target == "" then
        -- Attempt to find the video file from the Aegisub Project Garbage section
        local bufname = api.nvim_buf_get_name(bufnr)
        local buf_dir = fn.fnamemodify(bufname, ":h")
        local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local video_file

        for _, line in ipairs(lines) do
            if line:match("^Video File:%s*(.+)") then
                video_file = line:match("^Video File:%s*(.+)")
                break
            end
        end

        local fallback = util.fallback_video_path(bufname)

        if video_file then
            target = fn.fnamemodify(buf_dir .. "/" .. video_file, ":p")
            if not fn.filereadable(target) then
                logger.error("Video file not found: " .. target, true)
                if fallback then
                    target = fallback
                else
                    return
                end
            end
        else
            if fallback then
                target = fallback
            else
                logger.error("No video file found in Aegisub Project Garbage", true)
                return
            end
        end
    end

    -- Create an IPC socket path
    local sock = socket_path_for(bufnr)
    -- Ensure old socket is removed
    os.remove(sock)

    -- Launch MPV as a detached job
    local cmd = {
        "mpv",
        "--input-ipc-server=" .. sock,
        "--no-terminal",
        "--log-file=/dev/null",
        target,
    }
    local job_id = fn.jobstart(cmd, { detach = true })
    if job_id <= 0 then
        logger.error("Failed to launch MPV", true)
        return
    end

    -- initialize session
    M.sessions[bufnr] = {
        job_id = job_id,
        socket = sock,
        listeners = {},
    }

    -- vim.notify("MPV started (buf #" .. bufnr .. ")", vim.log.levels.INFO)
    logger.info("Buffer " .. bufnr .. ": MPV starting...", true)

    -- Wait up to 2 seconds, checking every 50ms
    wait_for_socket(sock, 2000, 50, function()
        vim.schedule(function()
            logger.debug("MPV socket ready, starting event reader", true)
        end)
        M._start_event_reader(bufnr)
        M.observe_defaults(bufnr)
        M.register_listeners(bufnr)
    end)
end

---
---Quit MPV for a specific buffer.
---Sends the "quit" command to MPV and cleans up the session.
---@param bufnr integer The buffer number.
---
M.quit_for_buf = function(bufnr)
    local sess = M.sessions[bufnr]
    if not sess then
        return
    end
    -- ask MPV to quit
    send_ipc(sess.socket, { command = { "quit" } })
    -- give it a moment, then kill the job if still alive
    vim.defer_fn(function()
        M._cleanup(bufnr)
    end, 200)
    logger.info("MPV stopped (buf #" .. bufnr .. ")", true)
end

---
---Quit the MPV session for the current buffer.
---
M.quit_current = function()
    M.quit_for_buf(api.nvim_get_current_buf())
end

---
---Toggle pause for the MPV session in the current buffer.
---
M.pause_current = function()
    send_ipc_buf(api.nvim_get_current_buf(), { command = { "cycle", "pause" } })
end

---
---Check if the buffer has a connected, running MPV process.
---@param bufnr integer The buffer number.
---@return boolean True if MPV is running, false otherwise.
---
M.is_running = function(bufnr)
    local sess = M.sessions[bufnr]
    if not sess then
        return false
    end
    return is_job_running(sess.job_id)
end

---
---Register a callback for an MPV event or property.
---@param bufnr integer The buffer number.
---@param event_name string The name of the event to listen for.
---@param cb function The callback function to invoke when the event occurs.
---
M.on = function(bufnr, event_name, cb)
    local sess = M.sessions[bufnr]
    if not sess then
        vim.notify("No MPV session for buffer " .. bufnr, vim.log.levels.WARN)
        return
    end
    sess.listeners[event_name] = sess.listeners[event_name] or {}
    table.insert(sess.listeners[event_name], cb)
end

---
---Start observing default MPV properties for a buffer.
---Observes properties like "pause" and "playback-time".
---@param bufnr integer The buffer number.
---
M.observe_defaults = function(bufnr)
    local sess = M.sessions[bufnr]
    if not sess then
        return
    end
    -- request-IDs are arbitrary, unique per property
    observe_property(bufnr, 1, "pause")
    observe_property(bufnr, 2, "playback-time")
end

---
---TODO
---Register default listener callbacks for MPV events in a buffer.
---@param bufnr integer The buffer number.
---
M.register_listeners = function(bufnr)
    M.on(bufnr, "pause", function(data)
        print("Paused: " .. tostring(data))
    end)
    M.on(bufnr, "playback-time", function(data)
        print("Playback-time: " .. tostring(data))
    end)
end

return M
