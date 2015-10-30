require "defines"

local _M = {}
local Logger = {prefix='misanthrope'}
Logger.__index = Logger

 -- tracks if the log file has ever been written to, for append vs replace in write_file
local ever_written = false

function Logger:log(str)
    local run_time_s = math.floor(game.tick/60)
    local run_time_minutes = math.floor(run_time_s/60)
    local run_time_hours = math.floor(run_time_minutes/60)
    self.log_buffer[#self.log_buffer + 1] = string.format("%02d:%02d:%02d: %s\r\n", run_time_hours, run_time_minutes % 60, run_time_s % 60, str)
    self:checkOutput()
    self:dump()
end

function Logger:checkOutput()
    if self.last_write_size ~= #self.log_buffer and (game.tick - self.last_write_tick) > 60 then
        self:dump()
    end
end

function Logger:dump()
    self.last_write_tick = game.tick
    self.last_write_size = #self.log_buffer
    local file_name = "logs/"..self.prefix.."/"..self.name..".log"
    game.write_file(file_name, table.concat(self.log_buffer), ever_written)
    self.log_buffer = {}
    ever_written = true
    return true
end

function Logger:toString(table, indent_level)
    indent_level = indent_level or 1
    
    if table == nil then
        return "nil"
    end
    if type(table) == "string" then
        return table
    end
    if type(table) == "boolean" then
        if table then
            return "true"
        else
            return "false"
        end
    end
    local str = ""
	for i,d in pairs(table) do
		local t = type(d)
		if t == "table" then
			str = str .. "\n" .. self._indents(self, indent_level) .. i .. " : " .. self.toString(self, d, indent_level + 1)
		else
			str = str .. "\n" .. self._indents(self, indent_level) .. i .." : "..tostring(d)
		end
	end
    return str
end

function Logger:_indents(indent_level)
    local str = ""
    for i=1, indent_level+1 do
        str = str .. "\t"
    end
    return str
end


function _M.new_logger(name)
    local temp = {name = name, log_buffer = {}, last_write_tick = 0, last_write_size = 0}
    local logger = setmetatable(temp, Logger)
    return logger
end
return _M
