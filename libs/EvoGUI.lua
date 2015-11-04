
EvoGUI = {}

function EvoGUI.new()
    local EvoGUI = { detected = false, exponential_moving_average = game.evolution_factor }

    if remote.interfaces.EvoGUI and remote.interfaces.EvoGUI.create_remote_sensor then
        EvoGUI.detected = true

        remote.call("EvoGUI", "create_remote_sensor", "Misanthrope", "evolution_state", "Evolution State:", "[Misanthrope] Evolution State")
        remote.call("EvoGUI", "create_remote_sensor", "Misanthrope", "evolution_rate", "Evolution Rate:", "[Misanthrope] Evolution Rate")
    end

    function EvoGUI:createEvolutionRateText()
        local diff = game.evolution_factor - self.exponential_moving_average
        if diff > 0 then
            return "Evolution Rate: +" .. string.format("%.3f", diff * 100 * 60 ) .. "% / min"
        else
            return "Evolution Rate: -" .. string.format("%.3f", math.abs(diff * 100 * 60)) .. "% / min"
        end
    end

    function EvoGUI:calculateEvolutionRateColor()
        local diff = game.evolution_factor - self.exponential_moving_average
        
        if diff > 0 then
            local red = (100 * 255 * diff) / 0.0035
            return { r = math.max(0, math.min(255, math.floor( red ))), g = math.max(0, math.min(255, math.floor( 255 - red ))), b = 0 }
        else
            return { r = 0, g = 255, b = 0 }
        end
    end

    function EvoGUI:createEvolutionText()
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

    function EvoGUI:tick()
        if self.detected and game.tick % 60 == 0 then
            self:updateGUI()
            self.exponential_moving_average = self.exponential_moving_average + (0.8 * (game.evolution_factor - self.exponential_moving_average))
        end
    end
    
    function EvoGUI:updateGUI()
        local expansion_data = EXPANSION_STATES[global.expansion_state]

        remote.call("EvoGUI", "update_remote_sensor", "evolution_state", self:createEvolutionText(), expansion_data.color)
        remote.call("EvoGUI", "update_remote_sensor", "evolution_rate", self:createEvolutionRateText(), self:calculateEvolutionRateColor())
    end
    
    EvoGUI:updateGUI()
    return EvoGUI
end

return EvoGUI
