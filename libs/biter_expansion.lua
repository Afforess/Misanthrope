
BiterExpansion = {}

expansion_phases = {}
table.insert(expansion_phases, require('expansion/peaceful'))
table.insert(expansion_phases, require('expansion/normal'))
table.insert(expansion_phases, require('expansion/passive'))
table.insert(expansion_phases, require('expansion/aggressive'))
table.insert(expansion_phases, require('expansion/assault'))
table.insert(expansion_phases, require('expansion/beachhead'))

function BiterExpansion.get_expansion_phase(index)
    return expansion_phases[index]
end

function BiterExpansion.new()
    local self = { expansion = expansion_phases }
    for i = 1, #self.expansion do
        self.expansion[i]["index"] = i
    end

    if not global.expansion_index then
		global.expansion_state = "peaceful"
        global.expansion_target_index = 1
        global.expansion_index = 1
        global.expansion_timer = 0
	end

    function self:tick()
        -- update expansion from command
        if global.expansion_phase_request ~= nil then
            self:set_expansion_state(self.expansion[global.expansion_phase_request.index])
            global.expansion_phase_request = nil
        end

        -- update expansion
        if global.expansion_timer > 0 then
            global.expansion_timer = global.expansion_timer - 1
            self:update_evolution_factor()
        else
            self:update_expansion_phase()
        end

        -- some expansions have on_tick logic, update if tick method exists
        local expansion_phase = self.expansion[global.expansion_index]
        if expansion_phase.tick then
            expansion_phase:tick()
        end

        -- apparently this is really slow
        if game.tick % 600 == 0 then
            self:update_expansion_factors(expansion_phase)
        end
    end

    function self:update_expansion_phase()
        if global.expansion_target_index > global.expansion_index then
            self:set_expansion_state(self.expansion[global.expansion_index + 1])
        else
            -- target expansion is the highest expansion level that is above our evolution factor
            for i = #self.expansion, 1, -1 do
                if game.evolution_factor > self.expansion[i].min_evo_factor then
                    global.expansion_target_index = i
                    Logger.log("Setting expansion target index to " .. i)
                    break
                end
            end
            -- No more peaceful mode after evolution factor of 50%
            if game.evolution_factor > 0.5 then
                self:set_expansion_state(self.expansion[2])
            else
                self:set_expansion_state(self.expansion[1])
            end
        end
    end

    function self:update_evolution_factor()
        if global.evo_factor > 0 then
            if game.evolution_factor < .001 then
                game.evolution_factor = 0
            else
                game.evolution_factor = game.evolution_factor - global.evo_factor
            end
        end
    end

    function self:set_expansion_state(state)
        Logger.log("Setting expansion state to: " .. state.name)
        Logger.log("Max Expansion state time " .. state.max_time)
        Logger.log("Min Expansion state time " .. state.min_time)

        global.expansion_timer = math.random(state.min_time, state.max_time)
        Logger.log("Setting expansion timer to: " .. global.expansion_timer)

        global.evo_factor = ((1 - state.evo_modifier) * game.evolution_factor) / global.expansion_timer
        Logger.log("Setting evo factor to: " .. global.evo_factor)

        global.expansion_index = state.index
        global.expansion_state = state.name
        global.last_expansion = game.tick
        state:update_expansion_state()

        self:reset_unit_group()

        game.map_settings.steering.moving.separation_force = 0.005
        game.map_settings.steering.moving.separation_factor = 1

        -- cause pollution to spread farther
        game.map_settings.pollution.diffusion_ratio = 0.05
        game.map_settings.pollution.min_to_diffuse = 10
        game.map_settings.pollution.expected_max_per_chunk = 6000
        Logger.log("Marathon mod enabled: " .. (self.is_marathon_enabled() and "true" or "false") .. ". RSO mod enabled: " .. (self.is_rso_enabled() and "true" or "false"))
    end

    function self:update_expansion_factors(state)
        if state.evo_modifier > 0.99999 then
            local ticks_played = game.tick
            -- more generous to marathon or rso players
            if self.is_marathon_enabled() then
                ticks_played = (ticks_played * 2) / 3
            end
            if self.is_rso_enabled() then
                ticks_played = (ticks_played * 2) / 3
            end

            -- At 12 hours, the time factor will be at 0.000004 (vanilla value).
            -- after 108 hours of game play, max value of 0.00008 will be reached
            local time_factor = math.min(0.00008, 0.000002 + 0.0000000000030864198 * ticks_played)
            -- after 64 hours of gameplay, max value of 0.00005 will be reached
            local pollution_factor = math.min(0.00005, 0.000005 + 0.0000000000028935186 * ticks_played)

            if global.harpa_list and global.idle_harpa_list then
                if #global.harpa_list > 0 or #global.idle_harpa_list > 0 then
                    time_factor = (time_factor * 3) / 2
                    pollution_factor = (pollution_factor * 3) / 2
                end
            end

            game.map_settings.enemy_evolution.time_factor = time_factor
            game.map_settings.enemy_evolution.pollution_factor = pollution_factor
        else
            game.map_settings.enemy_evolution.time_factor = 0
            game.map_settings.enemy_evolution.pollution_factor = 0
        end
    end

    function self.is_rso_enabled()
        return remote.interfaces.RSO ~= nil
    end

    function self.is_marathon_enabled()
        return game.item_prototypes["pipe"].stack_size == 100
    end

    -- Defaults from base/prototypes/map-settings.lua
    function self:reset_unit_group()
    	game.map_settings.unit_group.min_group_gathering_time = 3600
    	game.map_settings.unit_group.max_group_gathering_time = 10 * 3600

    	game.map_settings.unit_group.max_wait_time_for_late_members = 2 * 3600

    	game.map_settings.unit_group.max_group_radius = 30.0
    	game.map_settings.unit_group.min_group_radius = 5.0

    	game.map_settings.unit_group.max_member_speedup_when_behind = 1.4
    	game.map_settings.unit_group.tick_tolerance_when_member_arrives = 60
    end
    return self
end

return BiterExpansion
