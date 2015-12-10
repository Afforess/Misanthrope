
BiterExpansion = {}

local expansion_phases = {}
table.insert(expansion_phases, require('expansion/peaceful'))
table.insert(expansion_phases, require('expansion/normal'))
table.insert(expansion_phases, require('expansion/passive'))
table.insert(expansion_phases, require('expansion/aggressive'))
table.insert(expansion_phases, require('expansion/assault'))
table.insert(expansion_phases, require('expansion/beachhead'))

function BiterExpansion.new(logger)
    local self = { expansion = expansion_phases, logger = logger }
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
        self:update_expansion_factors(expansion_phase)
    end

    function self:update_expansion_phase()
        if global.expansion_target_index > global.expansion_index then
            self:set_expansion_state(self.expansion[global.expansion_index + 1])
        else
            -- target expansion is the highest expansion level that is above our evolution factor
            for i = #self.expansion, 1, -1 do
                if game.evolution_factor > self.expansion[i].min_evo_factor then
                    global.expansion_target_index = i
                    self.logger:log("Setting expansion target index to " .. i)
                    break
                end
            end
            self:set_expansion_state(self.expansion[1])
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
        self.logger:log("Setting expansion state to: " .. state.name)
        self.logger:log("Max Expansion state time " .. state.max_time)
        self.logger:log("Min Expansion state time " .. state.min_time)

        global.expansion_timer = math.random(state.min_time, state.max_time)
        self.logger:log("Setting expansion timer to: " .. global.expansion_timer)

        global.evo_factor = ((1 - state.evo_modifier) * game.evolution_factor) / global.expansion_timer
        self.logger:log("Setting evo factor to: " .. global.evo_factor)

        global.expansion_index = state.index
        global.expansion_state = state.name
        global.last_expansion = game.tick
        state:update_expansion_state()

        self:reset_unit_group()

        -- cause pollution to spread farther
        game.map_settings.pollution.diffusion_ratio = 0.04
        game.map_settings.pollution.min_to_diffuse = 50
        
        self.logger:log("Marathon mod enabled: " .. (self.is_marathon_enabled() and "true" or "false") .. ". RSO mod enabled: " .. (self.is_rso_enabled() and "true" or "false"))
    end

    function self:update_expansion_factors(state)
        if state.evo_modifier > 0.99999 then
            local ticks_played = game.tick
            -- more generous to marathon or rso players
            if self.is_marathon_enabled() then
                ticks_played = ticks_played / 2
            end
            if self.is_rso_enabled() then
                ticks_played = ticks_played / 2
            end
            -- At 12 hours, the time factor will be at 0.000004 (vanilla value).
            -- after 108 hours of game play, max value of 0.00002 will be reached
            game.map_settings.enemy_evolution.time_factor = math.min(0.00002, 0.000002 + 0.00000000000077160494 * game.tick)
            -- after 64 hours of gameplay, max value of 0.000025 will be reached
            game.map_settings.enemy_evolution.pollution_factor = math.max(0.000025, 0.000005 + 0.0000000000014467593 * game.tick)
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
