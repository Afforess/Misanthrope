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
	status, err = pcall(do_tick)
	if not status then
		Logger.log("Error (" .. serpent.line(err, {comment = false}) .. ") executing tick")
		for _, player in pairs(game.players) do
			if player.valid and player.connected then
				player.print("Error on_tick: " .. serpent.line(err, {comment = false}))
				player.print("Save and report to: https://goo.gl/48jbSz")
			end
		end
	end
end)

function do_tick()
	setup()
	map:tick()
	biter_expansion:tick()
	evo_gui:tick()
	Harpa.tick()
	pathfinder_demo.tick()
end

-- Strip backer names from HARPA emitters
script.on_event(defines.events.on_built_entity, function(event)
	if event.created_entity.name == "biter-emitter" then
		event.created_entity.backer_name = ""
		Harpa.register(event.created_entity, event.player_index)
	end
	update_regional_targets(event.created_entity)
	check_power(event.created_entity, nil)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
	if event.created_entity.name == "biter-emitter" then
		event.created_entity.backer_name = ""
		Harpa.register(event.created_entity, nil)
	end
	update_regional_targets(event.created_entity)
	check_power(event.created_entity, nil)
end)

script.on_event(defines.events.on_entity_died, function(event)
	local entity = event.entity
	check_power(entity, entity)
	if entity.type == "unit" and entity.force == game.forces.enemy then
		local region_data = region.lookup_region_from_position(entity.surface, entity.position)
		local cache = region.get_biter_scent_cache(region_data)
		biter_scents.entity_died(cache, entity)
	end
end)

script.on_event(defines.events.on_player_mined_item, function(event)
	if event and event.item_stack and event.item_stack.name and game.entity_prototypes[event.item_stack.name] then
		if game.entity_prototypes[event.item_stack.name].type == "electric-pole" then
			if game.players[event.player_index].character then
				Harpa.update_power_grid(game.players[event.player_index].character.position, 10, nil)
			else
				Harpa.update_power_grid(game.players[event.player_index].position, 10, nil)
			end
		end
	end
end)

function update_regional_targets(entity)
	if entity.force ~= game.forces.enemy and entity.force ~= game.forces.neutral then
		local region_data = region.lookup_region_from_position(entity.surface, entity.position)
		if region_data.player_target_cache and region_data.player_target_cache.calculated_at > 0 then
			player_target_cache.update(region_data.player_target_cache, entity)
		end
	end
end

function check_power(entity, ignore_entity)
	if entity.prototype.type == "electric-pole" then
		Harpa.update_power_grid(entity.position, 10, ignore_entity)
	end
end
