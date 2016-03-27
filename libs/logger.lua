require "defines"

Logger = {prefix='misanthrope', name = 'main', log_buffer = {}, last_write_tick = 0, last_write_size = 0, ever_written = false, debug = false}

function Logger.log(str)
    local run_time_s = 0
    local run_time_minutes = 0
    local run_time_hours = 0
    if _G["game"] then
        run_time_s = math.floor(game.tick/60)
        run_time_minutes = math.floor(run_time_s/60)
        run_time_hours = math.floor(run_time_minutes/60)
    end
    Logger.log_buffer[#Logger.log_buffer + 1] = string.format("%02d:%02d:%02d: %s\r\n", run_time_hours, run_time_minutes % 60, run_time_s % 60, str)
    Logger.checkOutput()
end

function Logger.checkOutput()
    if _G["game"] then
        if Logger.last_write_size ~= #Logger.log_buffer and (debug or (game.tick - Logger.last_write_tick) > 3600) then
            Logger.dump()
        end
    end
end

function Logger.dump()
    if _G["game"] then
        Logger.last_write_tick = game.tick
        Logger.last_write_size = #Logger.log_buffer
        local file_name = "logs/" .. Logger.prefix .. "/" .. Logger.name .. ".log"
        game.write_file(file_name, table.concat(Logger.log_buffer), Logger.ever_written)
        Logger.log_buffer = {}
        Logger.ever_written = true
        return true
    end
    return false
end
