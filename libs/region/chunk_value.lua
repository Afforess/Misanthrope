require 'stdlib/event/event'
require 'stdlib/area/position'
require 'stdlib/area/chunk'
require 'stdlib/area/tile'
require 'libs/biter_targets'

local Log = function(str, ...) World.Logger.log(string.format(str, ...)) end

Event.register({defines.events.on_entity_built, defines.events.on_robot_built_entity}, function(event)
    local entity = event.entity
    local pos = entity.position
    local chunk = Chunk.from_position(pos)
    local chunk_data = Chunk.get_data(entity.surface, chunk, {})
    local value = 1
    if BITER_TARGETS[entity.name] then
        value = BITER_TARGETS[entity.name].value
    end

    if chunk_data.player_value then
        chunk_data.player_value = chunk_data.player_value + value
    else
        chunk_data.player_value = value
    end
end)

function World.recalculate_chunk_values()
    local all_entities = Surface.find_all_entities({force = game.forces.player})
    Log("Total number of player entities: %d", #all_entities)
    for _, entity in pairs(all_entities) do
        if BITER_TARGETS[entity.name] then
            local value = BITER_TARGETS[entity.name].value
            local pos = entity.position
            local chunk = Chunk.from_position(pos)
            local chunk_data = Chunk.get_data(entity.surface, chunk, {})
            if chunk_data.player_value then
                chunk_data.player_value = chunk_data.player_value + value
            else
                chunk_data.player_value = value
            end
        end
    end
end
