require("prototypes.equipment.equipment")
require("prototypes.item.emitter")
require("prototypes.entity.emitter")
require("prototypes.recipes.emitter")
require("prototypes.technology.alien_defense")

for _, prototype in pairs(data.raw["unit-spawner"]) do
    prototype.pollution_absorbtion_absolute = prototype.pollution_absorbtion_absolute / 10
    prototype.pollution_absorbtion_absolute = prototype.pollution_absorbtion_proportional / 5
    prototype.max_count_of_owned_units = 0
    prototype.max_friends_around_to_spawn = 0
    prototype.spawning_cooldown = {9999999999,99999999999}
end

data.raw["unit"]["small-biter"].pollution_to_join_attack = 50
data.raw["unit"]["medium-biter"].pollution_to_join_attack = 150
data.raw["unit"]["big-biter"].pollution_to_join_attack = 300
data.raw["unit"]["behemoth-biter"].pollution_to_join_attack = 2000
data.raw["unit"]["small-spitter"].pollution_to_join_attack = 50
data.raw["unit"]["medium-spitter"].pollution_to_join_attack = 100
data.raw["unit"]["big-spitter"].pollution_to_join_attack = 200
data.raw["unit"]["behemoth-spitter"].pollution_to_join_attack = 1000
