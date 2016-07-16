require 'stdlib/string'

for _, prototype in pairs(data.raw["unit-spawner"]) do
    prototype.pollution_absorbtion_absolute = prototype.pollution_absorbtion_absolute / 10
    prototype.pollution_absorbtion_absolute = prototype.pollution_absorbtion_proportional / 5
    prototype.max_count_of_owned_units = 0
    prototype.max_friends_around_to_spawn = 0
    prototype.spawning_cooldown = {9999999999,99999999999}
    prototype.attack_reaction = {
        {
            range = 50,
            action =
            {
                type = "direct",
                action_delivery =
                {
                    type = "instant",
                    source_effects =
                    {
                        {
                            type = "create-entity",
                            entity_name = "spawner-damaged",
                            trigger_created_entity = "true"
                        }
                    }
                }
            }
        }
    }
end

data.raw["unit"]["small-biter"].pollution_to_join_attack = 50
data.raw["unit"]["medium-biter"].pollution_to_join_attack = 150
data.raw["unit"]["big-biter"].pollution_to_join_attack = 300
data.raw["unit"]["behemoth-biter"].pollution_to_join_attack = 2000
data.raw["unit"]["small-spitter"].pollution_to_join_attack = 50
data.raw["unit"]["medium-spitter"].pollution_to_join_attack = 100
data.raw["unit"]["big-spitter"].pollution_to_join_attack = 200
data.raw["unit"]["behemoth-spitter"].pollution_to_join_attack = 1000

for key, prototype_type in pairs(data.raw) do
    for name, prototype in pairs(prototype_type) do
        if prototype.energy_source then
            if prototype.energy_source.emissions and prototype.energy_source.emissions > 0.001 then
                if name:contains('assembling-machine') and not name == 'assembling-machine-1' then
                    prototype.energy_source.emissions = prototype.energy_source.emissions * 10
                else
                    prototype.energy_source.emissions = prototype.energy_source.emissions * 7
                end
            end
        end
    end
end
