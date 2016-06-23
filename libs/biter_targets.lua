require 'libs/biter/biter'

Biters.targets = {}

table.insert(Biters.targets, {name = "big-electric-pole", value = 300, min_evolution = 0.9})
table.insert(Biters.targets, {name = "medium-electric-pole", value = 100, min_evolution = 0.7})
table.insert(Biters.targets, {name = "small-electric-pole", value = 60, min_evolution = 0.5})

table.insert(Biters.targets, {type = "roboport", value = 500, min_evolution = 0})
table.insert(Biters.targets, {type = "radar", value = 500, min_evolution = 0})
table.insert(Biters.targets, {type = "pipe", value = 10, min_evolution = 0})
table.insert(Biters.targets, {name = "pipe-to-ground", value = 50, min_evolution = 0})

table.insert(Biters.targets, {type = "transport-belt", value = 20, min_evolution = 0})
table.insert(Biters.targets, {type = "offshore-pump", value = 20, min_evolution = 0})
table.insert(Biters.targets, {type = "storage-tank", value = 20, min_evolution = 0})

table.insert(Biters.targets, {type = "solar-panel", value = 100, min_evolution = 0.5})
table.insert(Biters.targets, {type = "boiler", value = 25, min_evolution = 0.3})

function Biters.entity_value(entity)
    local entity_name = entity.name
    local entity_type = entity.type
    local evo_factor = game.evolution_factor
    for i = 1, #Biters.targets do
        local target_data = Biters.targets[i]
        if evo_factor > target_data.min_evolution then
            if target_data.name == entity_name then
                return target_data.value
            elseif target_data.type == entity_type then
                return target_data.value
            end
        end
    end
    return -1
end
