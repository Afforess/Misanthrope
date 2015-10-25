require "defines"
require "util"
local linked_list = require("libs/linked_list")
local Region = require 'libs/region'
local Map = require 'libs/map'

local logger = require 'libs/logger'
local l = logger.new_logger("main")

--[[
Expansion States:
-peaceful
	Expansion completely disabled
-normal
	Normal biter behavior (non-peaceful)
-passive expanding
	Expanding at a minimal pace, keeps away from player base
-aggressive expanding
	Expanding at a more rapid pace, but still keeping away from player base
-viral expanding
	Existing bases gain extra spawners, in addition to aggressively creating new bases
-beachhead
	Attempts to expand near player base
-assault
	Attempts to attack player bases
--]]

-- Odds of any particular state being chosen, out of the total #
-- Ex: chance of peaceful state is 240 / (240 + 60 + 40 + 30 + 20 + 10) or 60%
-- Current evolution factor is added to each state chance. Because peaceful is only 1/6 possibilities
-- This skews any random state towards some aggressive one. Example with 25% evolution factor:
-- 		265 / (265 + 85 + 65 + 55 + 45 + 35) or 48%. With 100% evolution factor, peaceful state chance is down to 34%.
EXPANSION_STATES = {}
EXPANSION_STATES["peaceful"] = { odds = 240, max_time = 15 * 60 * 60, min_time = 15 * 60 * 60, min_evo_factor = 0, evo_modifier = 1, attack_rate = 0, assault_chance = 0}
EXPANSION_STATES["normal"] = { odds = 120, max_time = 15 * 60 * 60, min_time = 15 * 60 * 60, min_evo_factor = 0.15, evo_modifier = 1, attack_rate = 0, assault_chance = 0}
EXPANSION_STATES["passive_expanding"] = {odds = 60, max_time = 2 * 60 * 60, min_time = 1 * 60 * 60, min_evo_factor = 0.25, evo_modifier = 0.9, attack_rate = 60, assault_chance = 0}
EXPANSION_STATES["aggressive_expanding"] = {odds = 40, max_time = 3 * 60 * 60, min_time = 2 * 60 * 60, min_evo_factor = 0.35, evo_modifier = 0.85, attack_rate = 50, assault_chance = 0}
EXPANSION_STATES["viral_expanding"] = {odds = 30, max_time = 5 * 60 * 60, min_time = 3 * 60 * 60, min_evo_factor = 0.50, evo_modifier = 0.80, attack_rate = 30, assault_chance = 10}
EXPANSION_STATES["beachhead"] = {odds = 20, max_time = 8 * 60 * 60, min_time = 4 * 60 * 60, min_evo_factor = 0.65, evo_modifier = 0.75, attack_rate = 15, assault_chance = 50}
EXPANSION_STATES["assault"] = {odds = 10, max_time = 10 * 60 * 60, min_time = 5 * 60 * 60, min_evo_factor = 0.75, evo_modifier = 0.70, attack_rate = 15, assault_chance = 100}

local map = nil

script.on_init(setup)
local function setup()
	if not global.expansion_state then
		global.expansion_state = "peaceful"
	end
	if not global.expansion_timer then
		global.expansion_timer = 0
	end
	if not global.end_of_last_expansion then
		global.end_of_last_expansion = 0
	end
	if not global.evo_factor then
		global.evo_factor = 0
	end
	if not map then
		map = Map.new(l)
	end
	if not global.setup then
		global.setup = true
		l:log("expansion_state: "..global.expansion_state)
		l:log("expansion_timer: "..global.expansion_timer)
		l:log("end_of_last_expansion: "..global.end_of_last_expansion)
		l:log("evo_factor: "..global.evo_factor)
	end
end

local function chooseExpansionState()
	local total_odds = 0
	l:log("Total expansion states: "..#EXPANSION_STATES)
	l:log("Expansion states: "..l:toString(EXPANSION_STATES))
	
	for state,settings in pairs(EXPANSION_STATES) do
		if game.evolution_factor >= settings.min_evo_factor then
			local evo_odds = (settings.odds + math.floor(game.evolution_factor * 100))
			total_odds = total_odds + evo_odds
			l:log("Odds of expansion state ["..state.."] are "..evo_odds)
		end
	end
	l:log("Total odds for expansion states is "..total_odds)
	
	local expansion_chance = math.random(0, total_odds)
	l:log("Rolled expansion chance of "..expansion_chance)
	
	local expansion_state = "peaceful"
	for state,settings in pairs(EXPANSION_STATES) do
		if game.evolution_factor >= settings.min_evo_factor then
			local evo_odds = (settings.odds + math.floor(game.evolution_factor * 100))
			if (expansion_chance < evo_odds) then
				expansion_state = state 
				break
			end
			expansion_chance = expansion_chance - evo_odds
		end
	end
	
	l:log("Chosen expansion state: "..l:toString(expansion_state))
	l:dump()
	setExpansionState(expansion_state)
end

script.on_event(defines.events.on_tick, function(event)
	setup()
	map:tick()

	if global.expansion_state == "peaceful" then
		-- recalculate expansion phase every 15 min
		if (game.tick - global.end_of_last_expansion) % (15 * 60 * 60) == 0 then
			if game.evolution_factor >= 0.15 then
				chooseExpansionState()
			end
		end

		-- slowly restore the max steps worked per tick back to 100 (decreases by 1 per second)
		if game.tick % 60 == 0 and game.map_settings.path_finder.max_steps_worked_per_tick > 100 then
			game.map_settings.path_finder.max_steps_worked_per_tick = game.map_settings.path_finder.max_steps_worked_per_tick - 1
		end
	else
		local state = EXPANSION_STATES[global.expansion_state]
		if not global.assault and state.attack_rate > 0 and game.tick % (state.attack_rate * 60) == 0 then
			-- prod biters into attacking player / base
			for i=1, #game.players do
				if game.players[i].connected then
					game.get_surface(1).build_enemy_base(game.players[i].position, 100)
					l:log("Attempting to build biter base at player position of "..l:toString(game.players[i].position))
				end
			end
		end
		if global.assault and global.expansion_timer % 300 == 0 then
			global.assault_group = {}
			for i=1, #game.players do
				if game.players[i].connected then
					-- local enemies = game.get_surface(1).find_enemy_units(game.players[i].position, 750)
					-- local nearest_spawner = findNearestEntity(game.players[i].position, {"biter-spawner", "spitter-spawner"})
					-- if nearest_spawner ~= nil then
					-- 	for j=1, #enemies do
					-- 		enemies[j].set_command({type = defines.command.go_to_location, destination = nearest_spawner.position, radius = 60, distraction = defines.distraction.by_damage})
					-- 		global.assault_group[#global.assault_group + 1] = { entity = enemies[j], position = game.players[i].position }
					-- 	end
					-- 	l:log("Attempting to form up assault group at "..l:toString(nearest_spawner.position))
					-- end
					
					game.players[i].surface.set_multi_command({type = defines.command.attack, target = game.players[i].character, distraction = defines.distraction.by_enemy}, 100)
				end
			end
		end
		if global.assault and #global.assault_group > 0 and global.expansion_timer == 120 then
			l:log("Starting assault")
			for i=1, #global.assault_group do
				assault_entity = global.assault_group[i].entity
				if assault_entity ~= nil and assault_entity.valid then
					assault_pos = global.assault_group[i].position
					assault_entity.set_command({type = defines.command.attack_area, destination = assault_pos, radius = 15, distraction = defines.distraction.by_anything})
				end
			end
			global.assault_group = {}
			global.assault = false
		end
	end

	if global.expansion_state ~= "peaceful" then
		if global.expansion_timer > 0 then
			global.expansion_timer = global.expansion_timer - 1
			
			if game.evolution_factor < .001 then
				game.evolution_factor = 0
			else
				game.evolution_factor = game.evolution_factor - global.evo_factor
			end
		else
			setExpansionState("peaceful")
		end
	end
end)

function setExpansionState(expansion_state)
	l:log("Setting expansion state to: "..expansion_state)
	l:log("Max Expansion state time "..EXPANSION_STATES[expansion_state].max_time)
	l:log("Min Expansion state time "..EXPANSION_STATES[expansion_state].min_time)

	global.expansion_timer = math.random(EXPANSION_STATES[expansion_state].min_time, EXPANSION_STATES[expansion_state].max_time)
	l:log("Setting expansion timer to: "..global.expansion_timer)

	local assault_roll = math.random(0, 100)
	global.assault = assault_roll < EXPANSION_STATES[expansion_state].assault_chance
	l:log("Expansion assault roll: "..assault_roll..", assault_chance: "..EXPANSION_STATES[expansion_state].assault_chance)
	
	global.evo_factor = ((1 - EXPANSION_STATES[expansion_state].evo_modifier) * game.evolution_factor) / global.expansion_timer
	l:log("Setting evo factor to: "..global.evo_factor)
	
	resetUnitGroup()
	
	-- cause pollution to spread farther
	game.map_settings.pollution.diffusion_ratio = 0.04
	game.map_settings.pollution.min_to_diffuse = 50
	
	-- penalize time more, and pollution a bit less (to compensate for the expanded spread)
	game.map_settings.time_factor = 0.000004 * 4
	game.map_settings.pollution_factor = 0.000015 / 2

	
	-- allow biters to path from farther away (minor performance hit)
	if expansion_state == "peaceful" then
		game.map_settings.max_failed_behavior_count = 3
	else
		game.map_settings.path_finder.max_steps_worked_per_tick = 500
		game.map_settings.max_failed_behavior_count = 10
	end
	
	if expansion_state == "peaceful" then
		game.map_settings.enemy_expansion.enabled = false
		global.expansion_timer = 0
		global.end_of_last_expansion = game.tick

	elseif expansion_state == "normal" then
		game.map_settings.enemy_expansion.enabled = true
		
		-- vanilla map settings
		game.map_settings.enemy_expansion.min_base_spacing = 3
		game.map_settings.enemy_expansion.max_expansion_distance = 7
		game.map_settings.enemy_expansion.min_player_base_distance = 3
		game.map_settings.enemy_expansion.settler_group_min_size = 5
		game.map_settings.enemy_expansion.settler_group_max_size = 20
		game.map_settings.enemy_expansion.min_expansion_cooldown = 5 * 3600
		game.map_settings.enemy_expansion.max_expansion_cooldown = 60 * 3600
		
		game.map_settings.unit_group.max_member_speedup_when_behind = 1.4
		
	elseif expansion_state == "passive_expanding" then
		game.map_settings.enemy_expansion.enabled = true
		game.map_settings.enemy_expansion.min_base_spacing = 4
		game.map_settings.enemy_expansion.max_expansion_distance = 6
		game.map_settings.enemy_expansion.min_player_base_distance = 10
		game.map_settings.enemy_expansion.settler_group_min_size = 4
		game.map_settings.enemy_expansion.settler_group_max_size = 8
		game.map_settings.enemy_expansion.min_expansion_cooldown = 10 * 60
		game.map_settings.enemy_expansion.max_expansion_cooldown = 30 * 60

	elseif expansion_state == "aggressive_expanding" then
		game.map_settings.enemy_expansion.enabled = true
		game.map_settings.enemy_expansion.min_base_spacing = 3
		game.map_settings.enemy_expansion.max_expansion_distance = 8
		game.map_settings.enemy_expansion.min_player_base_distance = 6
		game.map_settings.enemy_expansion.settler_group_min_size = 15
		game.map_settings.enemy_expansion.settler_group_max_size = 30
		game.map_settings.enemy_expansion.min_expansion_cooldown = 5 * 60
		game.map_settings.enemy_expansion.max_expansion_cooldown = 25 * 60
		
		game.map_settings.unit_group.max_member_speedup_when_behind = 2

	elseif expansion_state == "viral_expanding" then
		game.map_settings.enemy_expansion.enabled = true
		game.map_settings.enemy_expansion.min_base_spacing = 1
		game.map_settings.enemy_expansion.max_expansion_distance = 10
		game.map_settings.enemy_expansion.min_player_base_distance = 3
		game.map_settings.enemy_expansion.settler_group_min_size = 20
		game.map_settings.enemy_expansion.settler_group_max_size = 60
		game.map_settings.enemy_expansion.min_expansion_cooldown = 5 * 60
		game.map_settings.enemy_expansion.max_expansion_cooldown = 20 * 60
		
		game.map_settings.unit_group.max_group_radius = 60
		game.map_settings.unit_group.max_member_speedup_when_behind = 3

	elseif expansion_state == "beachhead" then
		game.map_settings.enemy_expansion.enabled = true
		game.map_settings.enemy_expansion.min_base_spacing = 2
		game.map_settings.enemy_expansion.max_expansion_distance = 2
		game.map_settings.enemy_expansion.min_player_base_distance = 0
		game.map_settings.enemy_expansion.settler_group_min_size = 30
		game.map_settings.enemy_expansion.settler_group_max_size = 75
		game.map_settings.enemy_expansion.min_expansion_cooldown = 5 * 60
		game.map_settings.enemy_expansion.max_expansion_cooldown = 20 * 60
		
		game.map_settings.unit_group.max_group_radius = 60
		game.map_settings.unit_group.max_member_speedup_when_behind = 4

	elseif expansion_state == "assault" then
		game.map_settings.enemy_expansion.enabled = false
		
		game.map_settings.unit_group.max_group_radius = 100
		game.map_settings.unit_group.max_member_speedup_when_behind = 6

	end
	-- 
	-- global.assault_group = {}
	-- if global.assault then
	-- 	-- cause a total assault
	-- 	for i=1, #game.players do
	-- 		if game.players[i].connected then
	-- 			local enemies = game.get_surface(1).find_enemy_units(game.players[i].position, 750)
	-- 			local nearest_spawner = findNearestEntity(game.players[i].position, {"biter-spawner", "spitter-spawner"})
	-- 			if nearest_spawner ~= nil then
	-- 				for j=1, #enemies do
	-- 					enemies[j].set_command({type = defines.command.go_to_location, destination = nearest_spawner.position, radius = 60, distraction = defines.distraction.by_damage})
	-- 					global.assault_group[#global.assault_group + 1] = { entity = enemies[j], position = game.players[i].position }
	-- 				end
	-- 				l:log("Attempting to form up assault group at "..l:toString(nearest_spawner.position))
	-- 			end
	-- 		end
	-- 	end
	-- end

	l:log("Enemy Expansion table: "..l:toString(game.map_settings.enemy_expansion))
	
	global.expansion_state = expansion_state
	l:log("Expansion state set to: " .. global.expansion_state)
	l:log("Timer is: " .. (global.expansion_timer / 60) .. " seconds")
	l:dump()
end

-- Defaults from base/prototypes/map-settings.lua
function resetUnitGroup()
	game.map_settings.unit_group.min_group_gathering_time = 3600
	game.map_settings.unit_group.max_group_gathering_time = 10 * 3600
	
	game.map_settings.unit_group.max_wait_time_for_late_members = 2 * 3600

	game.map_settings.unit_group.max_group_radius = 30.0
	game.map_settings.unit_group.min_group_radius = 5.0

	game.map_settings.unit_group.max_member_speedup_when_behind = 1.4
	game.map_settings.unit_group.tick_tolerance_when_member_arrives = 60
end

function findNearestEntity(position, nameList)
	local entities = findEntitiesInGeneratedChunks(nameList)
	local closest_entity = nil
	local closest_distance = -1
	for i=1, #entities do
		local x_dist = entities[i].position.x - position.x
		local y_dist = entities[i].position.y - position.y
		local dist_squared = (x_dist * x_dist) + (y_dist * y_dist)
		if dist_squared < closest_distance or closest_distance == -1 then
			closest_entity = entities[i]
			closest_distance = dist_squared
		end
	end
	return closest_entity
end

function findEntitiesInGeneratedChunks(nameList)
	local entityList = {}
	for chunk in game.get_surface(1).get_chunks()
	do
		if game.get_surface(1).is_chunk_generated(chunk)
		then
			for i=1, #nameList
			do
				local temp = game.get_surface(1).find_entities_filtered({area = chunkArea(chunk), name = nameList[i]})
				entityList = mergeTables(entityList, temp)
			end
		end
	end
	return entityList
end

function chunkArea(chunk)
	position1 = {x = chunk.x*32, y = chunk.y*32}
	position2 = {x = chunk.x*32+32, y = chunk.y*32+32}
	area = {lefttop = position1, rightbottom = position2}
	return area
end

function mergeTables(table1, table2)
	newTable = table1
	for i=1, #table2
	do
		table.insert(newTable, table2[i])
	end
	return newTable
end
