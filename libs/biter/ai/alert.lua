
local Alert = {}
local Log = function(str, ...) BiterBase.Logger.log(string.format(str, ...)) end

function Alert.tick(base, data)
    if data.alerted_at + (60 * 60 * 5) < game.tick then
        Log("%s | Alert: Last alert was > 5 minutes ago.", BiterBase.tostring(base))
        return false
    end
    if base.entities then
        base.entities = table.filter(base.entities, Game.VALID_FILTER)
        if #base.entities > 15 then
            return true
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
        -- normal wander behavior
        unit_group.set_command({type = defines.command.attack_area, destination = base.queen.position, radius = 16})
        unit_group.start_moving()
    end
    return true
end


return Alert
