require 'stdlib/event/event'

Event.register(defines.events.on_tick, function(event)
    -- enforce map settings
    if event.tick % 3600 == 0 then
        local map_settings = game.map_settings
        -- truncate to 3 digits (ex: 0.756)
        local research_progress = math.floor(Evolution.research_progress() * 1000) / 1000
        map_settings.steering.moving.separation_force = 0.005
        map_settings.steering.moving.separation_factor = 1

        -- cause pollution to spread farther
        map_settings.pollution.diffusion_ratio = math.max(0.03, 0.1 * research_progress)
        map_settings.pollution.min_to_diffuse = 10
        map_settings.pollution.expected_max_per_chunk = 6000

        map_settings.enemy_evolution.enabled = true
        map_settings.enemy_evolution.time_factor = math.min(0.000001, 0.000032 * research_progress)
        map_settings.enemy_evolution.pollution_factor = 0.000008 * research_progress
        map_settings.enemy_evolution.destroy_factor = -0.002

        local evo_factor = game.evolution_factor
        if evo_factor < 0 then
            game.evolution_factor = 0
            evo_factor = 0
        end
        global.evo_modifier = 0
        if evo_factor > 0.4 and not Evolution.is_any_laser_turrets_researched() then
            global.evo_modifier = ((evo_factor - 0.4) / 6) / 60
        elseif evo_factor > 0.1 and not Evolution.is_any_turrets_researched() then
            global.evo_modifier = ((evo_factor - 0.1) / 2) / 60
        end
    end
    if event.tick % 60 == 0 then
        if global.evo_modifier > 0 then
            game.evolution_factor = game.evolution_factor - global.evo_modifier
        end
    end
end)

Evolution = {}
function Evolution.player_forces()
    return table.filter(game.forces, function(force, name) return name ~= 'neutral' and name ~= 'enemy' end)
end

function Evolution.research_progress()
    local researched = 0
    local total = 0
    table.each(Evolution.player_forces(), function(force, name)
        for tech_name, tech in pairs(force.technologies) do
            total = total + 1
            if tech.researched then
                researched = researched + 1
            end
        end
    end)
    if total > 0 then
        return researched / total
    end
    return 0
end

function table.is_empty(tbl)
    return next(tbl) ~= nil
end

function Evolution.is_any_laser_turrets_researched()
    return table.is_empty(table.filter(Evolution.player_forces(), function(force)
        return table.is_empty(Evolution.find_all_buildable_laser_turrets(force))
    end))
end

function Evolution.is_any_turrets_researched()
    return table.is_empty(table.filter(Evolution.player_forces(), function(force)
        return table.is_empty(Evolution.find_all_buildable_turrets(force))
    end))
end

function Evolution.find_all_buildable_laser_turrets(force)
    return table.filter(Evolution.find_all_buildable_turrets(force), function(prototype, name)
        return name and name:contains('laser')
    end)
end

-- cache for a value that only changes once per game load anyway
Evolution._find_all_buildable_turrets = nil
function Evolution.find_all_buildable_turrets(force)
    if not Evolution.__find_all_buildable_turrets then
        Evolution.__find_all_buildable_turrets = {}
    end
    local force_name = force.name
    if not Evolution.__find_all_buildable_turrets[force_name] then
        Evolution.__find_all_buildable_turrets[force_name] = Evolution._find_all_buildable_turrets(force)
    end
    return Evolution.__find_all_buildable_turrets[force_name]
end

function Evolution._find_all_buildable_turrets(force)
    local recipes = force.recipes
    return table.filter(Evolution.find_all_turret_prototypes(), function(prototype, name)
        return recipes[name] and recipes[name].enabled
    end)
end

function Evolution.find_all_turret_prototypes()
    local prototypes = {}
    table.each(table.filter(game.entity_prototypes, function(prototype)
        return Entity.has(prototype, "turret_range") and prototype.turret_range > 0
    end), function(prototype)
        prototypes[prototype.name] = prototype
    end)
    return prototypes
end
