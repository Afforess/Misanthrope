
local Alert = {}
local Log = function(str, ...) BiterBase.Logger.log(string.format(str, ...)) end

function Alert.tick(base, data)
    if #base:get_entities() < 15 then
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
            -- normal wander behavior
            unit_group.set_command({type = defines.command.attack_area, destination = base.queen.position, radius = 16})
            unit_group.start_moving()
        end
    end
    return true
end

function Alert.is_expired(base, data)
    return data.alerted_at + Time.MINUTE * 5 < game.tick
end

return Alert
