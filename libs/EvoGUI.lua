
local evoGUI_init = false
local evoGUI_detected = false
function init_EvoGUI()
    if evoGUI_init then
        return
    end
    evoGUI_init = true
    
    if remote.interfaces.EvoGUI and remote.interfaces.EvoGUI.create_remote_sensor then
        evoGUI_detected = true
        
        local expansion_data = EXPANSION_STATES[global.expansion_state]
        remote.call("EvoGUI", "create_remote_sensor", "evolution_state", createEvolutionText(), "[Misanthrope] Evolution State", expansion_data.color)
    end
end

function createEvolutionText()
    local expansion_data = EXPANSION_STATES[global.expansion_state]
    local text = "Evolution State: " .. expansion_data.name
    if global.expansion_state == "peaceful" then
        local ticks_left = (15 * 60 * 60) - (game.tick - global.end_of_last_expansion)

        text = text .. " ( " .. math.floor(ticks_left / 60) .. "s )"
    else
        text = text .. " ( " .. math.floor(global.expansion_timer / 60) .. "s )"
    end
    return text
end

function updateEvoGUI()
    if evoGUI_detected then
        local expansion_data = EXPANSION_STATES[global.expansion_state]

        remote.call("EvoGUI", "update_remote_sensor", "evolution_state", createEvolutionText(), expansion_data.color)
    end
end
