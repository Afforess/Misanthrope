require "defines"
require "util"
require 'libs/logger'
require 'remote'
require 'libs/EvoGUI'
require 'libs/map'
require 'libs/biter_expansion'
require 'libs/pathfinder_demo'
local Harpa = require "libs/harpa"

local map = nil
local biter_expansion = nil
local evo_gui = nil

script.on_init(setup)
script.on_load(setup)
local function setup()
	if not map then
		map = Map.new(l)
	end
	if not biter_expansion then
		biter_expansion = BiterExpansion.new(l)
	end
	if not evo_gui then
		evo_gui = EvoGUI.new(biter_expansion.expansion)
	end
end

script.on_event(defines.events.on_tick, function(event)
	setup()
	map:tick()
	biter_expansion:tick()
	evo_gui:tick()
	Harpa.tick()
	pathfinder_demo.tick()
end)

-- Strip backer names from HARPA emitters
script.on_event(defines.events.on_built_entity, function(event)
	if event.created_entity.name == "biter-emitter" then
		event.created_entity.backer_name = ""
		Harpa.register(event.created_entity, event.player_index)
	end
	update_regional_targets(event.created_entity)
	update_danger_cache(event.created_entity)
	check_power(event.created_entity, nil)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
	if event.created_entity.name == "biter-emitter" then
		event.created_entity.backer_name = ""
		Harpa.register(event.created_entity, nil)
	end
	update_regional_targets(event.created_entity)
	update_danger_cache(event.created_entity)
	check_power(event.created_entity, nil)
end)

script.on_event(defines.events.on_entity_died, function(event)
	check_power(event.entity, event.entity)
end)

script.on_event(defines.events.on_player_mined_item, function(event)
	if event and event.item_stack and event.item_stack.name and game.entity_prototypes[event.item_stack.name] then
		if game.entity_prototypes[event.item_stack.name].type == "electric-pole" then
			Harpa.update_power_grid(game.players[event.player_index].character.position, 10, nil)
		end
	end
end)

function update_regional_targets(entity)
	if entity.force ~= game.forces.enemy and entity.force ~= game.forces.neutral then
		local region_data = region.lookup_region_from_position(entity.surface, entity.position)
		if not region_data.any_targets then
			Logger.log(region.tostring(region_data) .. " has available targets, cache cleared.")
		end
		region_data.any_targets = false
	end
end

function update_danger_cache(entity)
	if entity.force ~= game.forces.enemy and entity.force ~= game.forces.neutral then
		local region_data = region.lookup_region_from_position(entity.surface, entity.position)
		local turret_names = {"laser-turret", "gun-turret", "gun-turret-2", "biter-emitter"}
		for i = 1, #turret_names do
			if entity.name == turret_names[i] then
				region_data.danger_cache = nil
				return true
			end
		end
	end
	return false
end

function check_power(entity, ignore_entity)
	if entity.prototype.type == "electric-pole" then
		Harpa.update_power_grid(entity.position, 10, ignore_entity)
	end
end
