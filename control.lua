require "defines"
require "util"
require 'remote'
require 'libs/EvoGUI'
require 'libs/map'
require 'libs/biter_expansion'

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
end)

function mergeTables(table1, table2)
	newTable = table1
	for i=1, #table2
	do
		table.insert(newTable, table2[i])
	end
	return newTable
end
