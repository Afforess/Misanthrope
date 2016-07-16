
local GrowHive = {stages = {}}
local Log = function(str, ...) BiterBase.LogAI("[GrowHive] " .. str, ...) end

GrowHive.stages.clear_trees = function(base, data)
    local surface = base.queen.surface
    local pos = base.queen.position
    table.each(surface.find_entities_filtered({area = Position.expand_to_area(pos, data.search_distance), type = 'tree'}), function(entity)
        entity.destroy()
    end)
    return 'build_hive'
end

GrowHive.stages.build_hive = function(base, data)
    local surface = base.queen.surface
    local pos = base.queen.position
    local entity_pos = surface.find_non_colliding_position(data.hive_type, pos, data.search_distance, 0.5)
    if entity_pos and Position.distance(pos, entity_pos) <= data.search_distance then
        local hive = surface.create_entity({name = data.hive_type, position = entity_pos, direction = math.random(7), force = base.queen.force})
        table.insert(base.hives, hive)
        Log("Successfully spawned a new hive at %s", base, serpent.line(hive.position))
        game.evolution_factor = math.max(0, game.evolution_factor - 0.0025)
        return 'success'
    end

    data.search_distance = data.search_distance + 1
    return 'clear_trees'
end

function GrowHive.tick(base, data)
    if not data.stage then
        data.stage = 'clear_trees'
    end
    local prev_stage = data.stage
    data.stage = GrowHive.stages[data.stage](base, data)
    if prev_stage ~= data.stage then
        Log("Updating stage from %s to %s", base, prev_stage, data.stage)
    end
    return true
end

function GrowHive.is_expired(base, data)
    return data.search_distance > 12 or data.stage == 'success'
end

function GrowHive.initialize(base, data)
    data.search_distance = 3
    if math.random(100) > 33 then
        data.hive_type = 'biter-spawner'
    else
        data.hive_type = 'spitter-spawner'
    end
end

return GrowHive
