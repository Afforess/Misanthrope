
local BuildWorm = {stages = {}}
local Log = function(str, ...) BiterBase.LogAI("[BuildWorm] " .. str, ...) end

BuildWorm.stages.clear_trees = function(base, data)
    local surface = base.queen.surface
    local pos = base.queen.position
    table.each(surface.find_entities_filtered({area = Position.expand_to_area(pos, data.search_distance), type = 'tree'}), function(entity)
        entity.destroy()
    end)
    return 'build_worm'
end

BuildWorm.stages.build_worm = function(base, data)
    local surface = base.queen.surface
    local pos = base.queen.position
    local entity_pos = surface.find_non_colliding_position(data.worm_type, pos, data.search_distance, 0.5)
    if entity_pos and Position.distance(pos, entity_pos) <= data.search_distance then
        local worm = surface.create_entity({name = data.worm_type, position = entity_pos, force = base.queen.force})
        table.insert(base.worms, worm)
        Log("Successfully spawned a new worm at %s", base, serpent.line(worm.position))
        game.evolution_factor = game.evolution_factor - 0.001
        return 'success'
    end

    data.search_distance = data.search_distance + 1
    return 'clear_trees'
end

function BuildWorm.tick(base, data)
    if not data.stage then
        data.stage = 'clear_trees'
    end
    local prev_stage = data.stage
    data.stage = BuildWorm.stages[data.stage](base, data)
    if prev_stage ~= data.stage then
        Log("Updating stage from %s to %s", base, prev_stage, data.stage)
    end
    return true
end

function BuildWorm.is_expired(base, data)
    return data.search_distance > 7 or data.stage == 'success'
end

function BuildWorm.initialize(base, data)
    data.search_distance = 2
    if game.evolution_factor > 0.66 and math.random(100) > 66 then
        data.worm_type = 'big-worm-turret'
    elseif game.evolution_factor > 0.4 and math.random(100) > 40 then
        data.worm_type = 'medium-worm-turret'
    else
        data.worm_type = 'small-worm-turret'
    end
end

return BuildWorm
