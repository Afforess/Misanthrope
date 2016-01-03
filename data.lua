require("prototypes.entity.power_short")
require("prototypes.equipment.equipment")
require("prototypes.item.emitter")
require("prototypes.entity.emitter")
require("prototypes.recipes.emitter")
require("prototypes.technology.alien_defense")

data.raw["unit-spawner"]["biter-spawner"].pollution_absorbtion_absolute = 2
data.raw["unit-spawner"]["biter-spawner"].pollution_absorbtion_proportional = 0.005

data.raw["unit-spawner"]["spitter-spawner"].pollution_absorbtion_absolute = 2
data.raw["unit-spawner"]["spitter-spawner"].pollution_absorbtion_proportional = 0.005

data.raw["unit"]["small-biter"].pollution_to_join_attack = 50
data.raw["unit"]["medium-biter"].pollution_to_join_attack = 150
data.raw["unit"]["big-biter"].pollution_to_join_attack = 300
data.raw["unit"]["behemoth-biter"].pollution_to_join_attack = 2000
data.raw["unit"]["small-spitter"].pollution_to_join_attack = 50
data.raw["unit"]["medium-spitter"].pollution_to_join_attack = 100
data.raw["unit"]["big-spitter"].pollution_to_join_attack = 200
data.raw["unit"]["behemoth-spitter"].pollution_to_join_attack = 1000
