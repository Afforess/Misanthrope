
local AttackedRecently = {}
local Log = function(str, base, ...) BiterBase.Logger.log(string.format("[AttackedRecently] - (" .. base.name .. "): " .. str, ...)) end

function AttackedRecently.tick(base, data)
    if #base:get_entities() < 30 then
        local surface = base.queen.surface

        local biters = base:get_prev_entities()
        for _, hive in pairs(base:all_hives()) do
            table.insert(biters, Biters.spawn_biter(base, surface, hive))
        end

        if #biters > 0 then
            local closest_player = AttackedRecently.closest_player_character(surface, base.queen.position, 56)
            local unit_group = BiterBase.create_unit_group(base, {position = biters[1].position, force = 'enemy'})
            for _, biter in pairs(biters) do
                unit_group.add_member(biter)
            end
            if closest_player then
                unit_group.set_command({type = defines.command.attack, target = closest_player})
                if data.idle_unit_groups then
                    table.each(table.filter(data.idle_unit_groups, Game.VALID_FILTER), function(unit_group)
                        unit_group.set_command({type = defines.command.attack, target = closest_player})
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
    end
    return true
end

function AttackedRecently.is_expired(base, data)
    return base.last_attacked + (Time.MINUTE * 3) < game.tick
end

function AttackedRecently.closest_player_character(surface, pos, dist)
    local closest_char = nil
    local closest = dist * dist
    for _, character in pairs(World.all_characters(surface)) do
        local dist_squared = Position.distance_squared(pos, character.position)
        if dist_squared < closest then
            closest_char = character
            closest = dist_squared
        end
    end
    return closest_char
end

return AttackedRecently
