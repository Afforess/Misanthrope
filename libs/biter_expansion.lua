
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

        self:resetUnitGroup()

        -- cause pollution to spread farther
        game.map_settings.pollution.diffusion_ratio = 0.04
        game.map_settings.pollution.min_to_diffuse = 50

        -- penalize time more, and pollution a bit less (to compensate for the expanded spread)
        -- penalize time and pollution more as the game time advances (10hrs, 24 hrs and 72 hrs respectively)
        if game.tick < (10 * 60 * 60 * 60) then
            game.map_settings.enemy_evolution.time_factor = 0.000004
            game.map_settings.enemy_evolution.pollution_factor = 0.000015 / 4
        elseif game.tick < (24 * 60 * 60 * 60) then
            game.map_settings.enemy_evolution.time_factor = 0.000004 * 2
            game.map_settings.enemy_evolution.pollution_factor = 0.000015 / 2
            global.evo_factor = global.evo_factor * 1.5
        elseif game.tick < (3 * 24 * 60 * 60 * 60) then
            game.map_settings.enemy_evolution.time_factor = 0.000004 * 6
            game.map_settings.enemy_evolution.pollution_factor = 0.000015
            global.evo_factor = global.evo_factor * 2
        else
            game.map_settings.enemy_evolution.time_factor = 0.000004 * 12
            game.map_settings.enemy_evolution.pollution_factor = 0.000015 * 3
            global.evo_factor = global.evo_factor * 3
        end
    end

    -- Defaults from base/prototypes/map-settings.lua
    function self:resetUnitGroup()
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
