
local AssistAlly = {}
local Log = function(str, ...) BiterBase.LogAI("[AssistAlly] " .. str, ...) end

function AssistAlly.tick(base, data)
    if #base:get_entities() < 75 then
        local surface = base.queen.surface

        local biters = base:get_prev_entities()
        for _, hive in pairs(base:all_hives()) do
            table.insert(biters, Biters.spawn_biter(base, surface, hive))
        end

        if #biters > 0 then
            local closest_player = World.closest_player_character(surface, data.ally_base.queen.position, 56)
            if closest_player then
                data.idle_units = table.filter(data.idle_units, Game.VALID_FILTER)
                table.each(data.idle_units, function(biter)
                    biter.set_command({type = defines.command.attack, target = closest_player})
                end)
                data.idle_units = {}
                for _, biter in pairs(biters) do
                    biter.set_command({type = defines.command.attack, target = closest_player})
                end
            else
                for _, biter in pairs(biters) do
                    biter.set_command({type = defines.command.attack_area, destination = data.ally_base.queen.position, radius = 25})
                    table.insert(data.idle_units, biter)
                end
            end
        end
    end
    return true
end

function AssistAlly.initialize(base, data)
    data.idle_units = {}
end

function AssistAlly.is_expired(base, data)
    return not data.ally_base.valid or not data.ally_base.queen.valid or data.ally_base.last_attacked + (Time.MINUTE * 3) < game.tick
end

return AssistAlly
