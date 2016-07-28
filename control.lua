DEBUG_MODE = false
UNIT_GROUP_EVENT_ID = script.generate_event_name()
local wrapper = function(wrap)
    return function(msg, options)
        if not options or not options.comments then
            if options then
                options.comment = false
                return wrap(msg, options)
            else
                return wrap(msg, {comment = false})
            end
        end
        return wrap(msg, options)
    end
end

if DEBUG_MODE then
    string.line = wrapper(serpent.line)
    string.block = wrapper(serpent.line)
    string.dump = wrapper(serpent.line)
else
    string.line = function() return 'debug mode disabled' end
    string.block = function() return 'debug mode disabled' end
    string.dump = function() return 'debug mode disabled' end
end

require 'stdlib/log/logger'
require 'stdlib/time'
require 'remote'
require 'libs/EvoGUI'
require 'libs/world'
require 'libs/map_settings'
require 'libs/harpa'
require 'libs/region/biter_scents'
require 'libs/region/chunk_value'

LOGGER = Logger.new("Misanthrope", "main", DEBUG_MODE)

function Chunk.to_string(chunk_pos)
    return "{x = " .. chunk_pos.x .. ", y = " .. chunk_pos.y .. "}"
end
