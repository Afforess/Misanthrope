
local AttackArea = {stages = {}}
local Log = function(str, ...) BiterBase.LogAI("[AttackArea] " .. str, ...) end

AttackArea.stages.attacking = function(base, data)
    if not data.attack_group.valid then
        local entities = base:get_entities()
        Log("Unit group invalid, valid entities: %d", base, #entities)

        if #entities == 0 then
            return 'fail'
        end
        local command = {type = defines.command.attack_area, destination = data.attack_target, radius = 18}
        local unit_group = BiterBase.create_unit_group(base, {position = entities[1].position, force = 'enemy'})
        for _, biter in pairs(entities) do
            if biter.unit_group and biter.unit_group.valid then
                biter.unit_group.destroy()
            end
            unit_group.add_member(biter)
        end
        unit_group.set_command(command)
        unit_group.start_moving()
        data.attack_group = unit_group
    end
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

    if #base:get_entities() > data.attack_group_size then
        return 'plan_attack'
    end
    return 'spawning'
end

AttackArea.stages.plan_attack = function(base, data)
    local candidates = base.targets.candidates
    if #candidates == 0 then
        base.targets = nil
        return 'fail'
    end
    local idx = math.random(#candidates)
    local chunk_pos = table.remove(candidates, idx)
    Log("Attack candidate: %s", base, Chunk.to_string(chunk_pos))
    if #candidates == 0 then
        base.targets = nil
    end

    local end_pos = Area.center(Chunk.to_area(chunk_pos))
    data.attack_target = end_pos
    local command = {type = defines.command.attack_area, destination = end_pos, radius = 18}
    local entities = base:get_entities()

    local unit_group = BiterBase.create_unit_group(base, {position = entities[1].position, force = 'enemy'})
    for _, biter in pairs(entities) do
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

function AttackArea.initialize(base, data)
    data.attack_group_size = math.floor(10 + game.evolution_factor / 0.025)
    if base:get_currency(false) > BiterBase.plans.attack_area.cost * 2 then
        base:spend_currency(BiterBase.plans.attack_area.cost)
        data.attack_group_size = data.attack_group_size + math.floor(15 + game.evolution_factor / 0.02)
    end
    Log("Attack group size: %d", base, data.attack_group_size)
end

function AttackArea.is_expired(base, data)
    if data.stage == 'fail' or data.stage == 'success' then
        return true
    end
    return data.attack_group and ( --[[not data.attack_group.valid or --]] game.tick > data.attack_tick + Time.MINUTE * 6)
end

return AttackArea
