require "defines"
require "util"
require 'remote'
require 'libs/EvoGUI'
require 'libs/map'
require 'libs/biter_expansion'
local Harpa = require "libs/harpa"

local logger = require 'libs/logger'
local l = logger.new_logger("main")

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
	Harpa.tick(l)
end)

-- Strip backer names from HARPA emitters
script.on_event(defines.events.on_built_entity, function(event)
	if event.created_entity.name == "biter-emitter" then
		event.created_entity.backer_name = ""
		Harpa.register(event.created_entity, event.player_index)
	end
	check_power(event.created_entity, nil)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
	if event.created_entity.name == "biter-emitter" then
		event.created_entity.backer_name = ""
		Harpa.register(event.created_entity, nil)
	end
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

function check_power(entity, ignore_entity)
	if entity.prototype.type == "electric-pole" then
		Harpa.update_power_grid(entity.position, 10, ignore_entity)
	end
end

function mergeTables(table1, table2)
	newTable = table1
	for i=1, #table2
	do
		table.insert(newTable, table2[i])
	end
	return newTable
end
