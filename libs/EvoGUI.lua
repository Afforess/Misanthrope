require 'stdlib/event/event'

EvoGUI = {}

function EvoGUI.create_evolution_rate_text()
    local diff = game.evolution_factor - global.exponential_moving_average
    -- percentage is decimal * 100, * 60 for per minute value
    local evo_rate_per_min = math.abs(diff * 100 * 60)

    -- this nonsense is because string.format(%.3f) is not safe in MP across platforms, but integer math is
    local whole_number = math.floor(evo_rate_per_min)
    local fractional_component = math.floor((evo_rate_per_min - whole_number) * 1000)
    local text = string.format("%d.%04d%%", whole_number, fractional_component)
    if diff > 0 then
        return "Evolution Rate: +" .. text .. " / min"
    else
        return "Evolution Rate: -" .. text .. " / min"
    end
end

function EvoGUI.create_biter_scent_text()
    local player = game.players[1]
    if player and player.valid and player.connected then
        local character = player.character
        if character and character.valid then
            local pos = character.position
            local data = Tile.get_data(character.surface, Tile.from_position(pos))
            if data and data.scent then
                return "Biter Scent: " .. data.scent
            end
        end
    end
    return "Biter Scent: 0"
end

function EvoGUI.create_chunk_value_text()
    local player = game.players[1]
    if player and player.valid and player.connected then
        local character = player.character
        if character and character.valid then
            local pos = character.position
            local data = Chunk.get_data(character.surface, Chunk.from_position(pos))
            if data and data.player_value then
                return "Chunk Value: " .. data.player_value
            end
        end
    end
    return "Chunk Value: 0"
end

function EvoGUI.create_evolution_rate_color()
    local diff = game.evolution_factor - global.exponential_moving_average

    if diff > 0 then
        local red = (100 * 255 * diff) / 0.0035
        return { r = math.max(0, math.min(255, math.floor( red ))), g = math.max(0, math.min(255, math.floor( 255 - red ))), b = 0 }
    else
        return { r = 0, g = 255, b = 0 }
    end
end

function EvoGUI.setup()
    if remote.interfaces.EvoGUI and remote.interfaces.EvoGUI.create_remote_sensor then
        global.evo_gui.detected = true

        remote.call("EvoGUI", "create_remote_sensor", {
            mod_name = "Misanthrope",
            name = "evolution_rate",
            text = "Evolution Rate:",
            caption = "Evolution Rate"
        })
        if DEBUG_MODE then
            remote.call("EvoGUI", "create_remote_sensor", {
                mod_name = "Misanthrope",
                name = "biter_scent",
                text = "Biter Scent:",
                caption = "Biter Scent"
            })

            remote.call("EvoGUI", "create_remote_sensor", {
                mod_name = "Misanthrope",
                name = "chunk_value",
                text = "Chunk Value:",
                caption = "Chunk Value"
            })
        end
        EvoGUI.update_gui()
    end
end

Event.register(defines.events.on_tick, function(event)
    if not global.evo_gui then global.evo_gui = {} end
    if not global.exponential_moving_average then
        global.exponential_moving_average = game.evolution_factor
    end

    if not global.evo_gui.detected then
        EvoGUI.setup()
        if remote.interfaces.EvoGUI and remote.interfaces.EvoGUI.remove_remote_sensor and remote.interfaces.EvoGUI.has_remote_sensor then
            if remote.call("EvoGUI", "has_remote_sensor", "evolution_state") then
                remote.call("EvoGUI", "remove_remote_sensor", "evolution_state")
            end
        end
    end

    if global.evo_gui.detected and event.tick % 10 == 0 then
        if remote.interfaces.EvoGUI then
            EvoGUI.update_gui()
            global.exponential_moving_average = global.exponential_moving_average + (0.8 * (game.evolution_factor - global.exponential_moving_average))
        end
    end
end)

function EvoGUI.update_gui()
    remote.call("EvoGUI", "update_remote_sensor", "evolution_rate", EvoGUI.create_evolution_rate_text(), EvoGUI.create_evolution_rate_color())
    if DEBUG_MODE then
        remote.call("EvoGUI", "update_remote_sensor", "biter_scent", EvoGUI.create_biter_scent_text())
        remote.call("EvoGUI", "update_remote_sensor", "chunk_value", EvoGUI.create_chunk_value_text())
    end
end

return EvoGUI
