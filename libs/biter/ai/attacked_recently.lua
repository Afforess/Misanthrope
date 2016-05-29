
local AttackedRecently = {}
local Log = function(str, ...) BiterBase.Logger.log(string.format(str, ...)) end

function AttackedRecently.tick(base, data)
    if base.last_attacked + (60 * 60 * 3) < game.tick then
        Log("%s | AttackedRecently: Last attack was > 3 minutes ago.", BiterBase.tostring(base))
        return false
    end
    if base.entities then
        base.entities = table.filter(base.entities, Game.VALID_FILTER)
        if #base.entities > 30 then
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
        local closest_player = AttackedRecently.closest_player(surface, base.queen.position, 56)
        local unit_group = surface.create_unit_group({position = biters[1].position, force = 'enemy'})
        for _, biter in pairs(biters) do
            unit_group.add_member(biter)
        end
        if closest_player then
            unit_group.set_command({type = defines.command.attack, target = closest_player.character})
            if data.idle_unit_groups then
                table.each(table.filter(data.idle_unit_groups, Game.VALID_FILTER), function(unit_group)
                    unit_group.set_command({type = defines.command.attack, target = closest_player.character})
                end)
                data.idle_unit_groups = nil
            end
        else
            unit_group.set_command({type = defines.command.attack_area, destination = base.queen.position, radius = 20})
            if not data.idle_unit_groups then data.idle_unit_groups = {} end
            table.insert(data.idle_unit_groups, unit_group)
        end
        unit_group.start_moving()
    end
    return true
end

function AttackedRecently.closest_player(surface, pos, dist)
    local closest_player = nil
    local closest = dist * dist
    for _, player in pairs(global.players) do
        if player.valid and player.connected then
            local character = player.character
            if character and character.valid and character.surface == surface then
                local dist_squared = Position.distance_squared(pos, character.position)
                if dist_squared < closest then
                    closest_player = player
                    closest = dist_squared
                end
            end
        end
    end
    return closest_player
end

return AttackedRecently
