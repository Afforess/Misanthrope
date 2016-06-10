
local MoveBase = {stages = {}}
local Log = function(str, base, ...) BiterBase.Logger.log(string.format("[MoveBase] - (" .. base.name .. "): " .. str, ...)) end

MoveBase.stages.setup = function(base, data)
    local all_base_entities = {}
    for _, hive in pairs(table.filter(base:all_hives(), Game.VALID_FILTER)) do
        table.insert(all_base_entities, hive)
    end
    for _, worm in pairs(table.filter(base.worms, Game.VALID_FILTER)) do
        table.insert(all_base_entities, worm)
    end
    data.base_entities = all_base_entities

    local target_pos = table.remove(data.path, 1)

    Log("Number of Base Entities: %d, Target Position: %s", base, #data.base_entities, serpent.line(target_pos))
    data.target_pos = target_pos
    data.offset = Position.subtract(target_pos, base.queen.position)
    Log("Number of Base Entities: %d, Offset Position: %s", base, #data.base_entities, serpent.line(data.offset))
    return 'move'
end

MoveBase.stages.move = function(base, data)
    if #data.base_entities == 0 then
        return 'setup'
    end
    local index = math.random(#data.base_entities)
    local entity = table.remove(data.base_entities, index)
    if entity.valid then
        local surface = entity.surface
        local old_pos = entity.position
        local offset_pos = Position.add(old_pos, data.offset)
        local type = entity.type
        local name = entity.name
        local direction = entity.direction
        local is_queen = entity == base.queen
        local entity_area = Entity.to_selection_area(entity)
        entity.destroy()

        table.each(surface.find_entities_filtered({ area = Area.offset(Area.expand(entity_area, 1), data.offset), force = 'neutral' }), function(entity)
            entity.destroy()
        end)

        local new_pos = surface.find_non_colliding_position(name, offset_pos, 4, 0.1)
        local new_entity = surface.create_entity({name = name, position = new_pos, direction = direction, force = 'enemy'})
        if is_queen then
            base.queen = new_entity
        elseif type == 'unit-spawner' then
            base.hives = table.filter(base.hives, Game.VALID_FILTER)
            table.insert(base.hives, new_entity)
        else
            base.worms = table.filter(base.worms, Game.VALID_FILTER)
            table.insert(base.worms, new_entity)
        end
        Log("Teleported (%s) from %s to %s", base, name, serpent.line(old_pos), serpent.line(new_entity.position))
    end
    if #data.base_entities > 0 then
        return 'move'
    end
    return 'setup'
end

function MoveBase.initialize(base, data)
    data.stage = 'setup'
    data.start_chunk = Chunk.from_position(base.queen.position)
    data.path = table.remove(base.target.paths, 1)
    base.target = nil
end

function MoveBase.tick(base, data)
    local biters = base:get_prev_entities()
    for _, biter in pairs(biters) do
        biter.destroy()
    end

    local prev_stage = data.stage
    data.stage = MoveBase.stages[data.stage](base, data)
    if prev_stage ~= data.stage then
        Log("Updating stage from %s to %s", base, prev_stage, data.stage)
    end

    return true
end

function MoveBase.is_expired(base, data)
    local chunk = Chunk.from_position(base.queen.position)
    return #data.path == 0 or (chunk.x ~= data.start_chunk.x or chunk.y ~= data.start_chunk.y)
end

return MoveBase
