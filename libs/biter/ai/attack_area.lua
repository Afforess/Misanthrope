
local AttackArea = {stages = {}}
local Log = function(str, base, ...) BiterBase.Logger.log(string.format("[AttackArea] - (" .. base.name .. "): " .. str, ...)) end

AttackArea.stages.attacking = function(base, data)
    return 'attacking'
end

AttackArea.stages.spawning = function(base, data)
    local surface = base.queen.surface

    local biters = base:get_prev_entities()
    for _, hive in pairs(base:all_hives()) do
        table.insert(biters, Biters.spawn_biter(base, surface, hive))
    end
    if #biters > 0 then
        local unit_group = BiterBase.create_unit_group(base, {position = biters[1].position, force = 'enemy'})
        for _, biter in pairs(biters) do
            unit_group.add_member(biter)
        end
        unit_group.set_command({type = defines.command.attack_area, destination = base.queen.position, radius = 8})
        unit_group.start_moving()
    end

    local attack_group_size = math.floor(15 + game.evolution_factor / 0.025)
    if #base:get_entities() > attack_group_size then
        return 'plan_attack'
    end
    return 'spawning'
end

AttackArea.stages.plan_attack = function(base, data)
    local commands = {}
    for i = 1, #base.target.path, 5 do
        table.insert(commands, {type = defines.command.go_to_location, destination = base.target.path[i]})
    end
    local end_pos = Area.center(Chunk.to_area(base.target.chunk_pos))
    table.insert(commands, {type = defines.command.attack_area, destination = end_pos, radius = 32})
    local command = {type = defines.command.compound, structure_type = defines.compoundcommandtype.return_last, commands = commands}
    Log("Command contents: %s", base, serpent.line(command))

    local unit_group = BiterBase.create_unit_group(base, {position = base.entities[1].position, force = 'enemy'})
    for _, biter in pairs(base.entities) do
        if biter.unit_group and biter.unit_group.valid then
            biter.unit_group.destroy()
        end
        unit_group.add_member(biter)
    end
    unit_group.set_command(command)
    unit_group.start_moving()

    data.attack_group = unit_group
    data.attack_tick = game.tick
    return 'attacking'
end

function AttackArea.tick(base, data)
    if not data.stage then
        data.stage = 'spawning'
    end
    local prev_stage = data.stage
    data.stage = AttackArea.stages[data.stage](base, data)
    if prev_stage ~= data.stage then
        Log("Updating stage from %s to %s", base, prev_stage, data.stage)
    end
    return true
end

function AttackArea.is_expired(base, data)
    return data.attack_group and (not data.attack_group.valid or game.tick > data.attack_tick + Time.MINUTE * 3)
end

return AttackArea
