
local AttackArea = {}
local Log = function(str, ...) BiterBase.Logger.log(string.format(str, ...)) end

function AttackArea.tick(base, data)
    if base.entities then
        local attack_group_size = math.floor(15 + game.evolution_factor / 0.025)
        base.entities = table.filter(base.entities, Game.VALID_FILTER)
        if #base.entities > attack_group_size then
            -- do attack
        end
    end

    local surface = base.queen.surface

    local biters = {}
    if data.prev_entities then
        biters = table.filter(data.prev_entities, Game.VALID_FILTER)
        data.prev_entities = nil
    end

    local biter = Biters.spawn_biter(base, surface, base.queen)
    if biter then
        table.insert(biters, biter)
    end
    for _, hive in pairs(base.hives) do
        local biter = Biters.spawn_biter(base, surface, hive)
        if biter then
            table.insert(biters, biter)
        end
    end
    if #biters > 0 then
        local unit_group = surface.create_unit_group({position = biters[1].position, force = 'enemy'})
        for _, biter in pairs(biters) do
            unit_group.add_member(biter)
        end
        unit_group.set_command({type = defines.command.attack_area, destination = base.queen.position, radius = 8})
        unit_group.start_moving()
    end
    return true
end

function AttackArea.launch_attack(base)
    local surface = base.queen.surface
    local unit_group = surface.create_unit_group({position = biters[1].position, force = 'enemy'})
    for _, biter in pairs(biters) do
        unit_group.add_member(biter)
    end

end

return AttackArea
