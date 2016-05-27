
local AttackedRecently = {}
local Log = function(str, ...) BiterBase.Logger.log(string.format(str, ...)) end

function AttackedRecently.tick(base)
    if data.base.last_attacked + (60 * 60 * 3) < game.tick then
        Log("%s | AttackedRecently: Last attack was > 3 minutes ago.", BiterBase.tostring(base))
        return false
    end
    local surface = base.queen.surface

    local biters = {}
    local biter = AttackedRecently.spawn_biter(base, surface, base.queen)
    if biter then
        table.insert(biters, biter)
    end
    for _, hive in pairs(base.hives) do
        local biter = AttackedRecently.spawn_biter(base, surface, hive)
        if biter then
            table.insert(biters, biter)
        end
    end
    if #biters > 0 then
        local closest_player = AttackedRecently.closest_player(surface, base.queen.position, 64)
        local unit_group = surface.create_unit_group({position = biters[1].position, force = 'enemy'})
        for _, biter in pairs(biters) do
            unit_group.add_member(biter)
        end
        if closest_player then
            unit_group.set_command({type = defines.command.attack, target = closest_player.character})
        else
            unit_group.set_command({type = defines.command.attack_area, destination = base.queen.position, radius = 40})
        end
    end
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
    return closest
end

function AttackedRecently.spawn_biter(base, surface, spawner)
    for _, unit_name in pairs(AttackedRecently.valid_units(spawner)) do
        local odds = 100 * AttackedRecently.unit_odds(unit_name)
        if odds > 0 and odds > math.random(100) then
            local spawn_pos = surface.find_non_colliding_position(unit_name, spawner.position, 6, 0.5)
            if spawn_pos then
                return World.create_entity(surface, {name = unit_name, position = spawn_pos, force = 'enemy'}, base.plan)
            end
        end
    end
    return nil
end

function AttackedRecently.unit_odds(name)
    local evo_factor = game.evolution_factor
    if name:contains('behemoth') and evo_factor > 0.7 then
        return (evo_factor - 0.7) * 2
    end
    if name:contains('big') and evo_factor > 0.4 then
        return (evo_factor - 0.4) * 1.3
    end
    if name:contains('medium') and evo_factor > 0.25 then
        return math.min(0.5, evo_factor - 0.25)
    end
    if name == 'small-spitter' and evo_factor > 0.15 then
        return 0.75
    end
    if name == 'small-biter' then
        return 1
    end
    return 0
end

function AttackedRecently.valid_units(spawner)
    if spawner.name == 'spitter-spawner' then
        return {'small-biter', 'small-spitter', 'medium-spitter', 'big-spitter', 'behemoth-spitter'}
    end
    return {'small-biter', 'medium-biter', 'big-biter', 'behemoth-biter'}
end

return IdentifyTargets
