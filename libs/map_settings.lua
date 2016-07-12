require 'stdlib/event/event'

Event.register(defines.events.on_tick, function(event)
    -- enforce map settings
    if event.tick % 3600 == 0 then
        local map_settings = game.map_settings
        map_settings.steering.moving.separation_force = 0.005
        map_settings.steering.moving.separation_factor = 1

        -- cause pollution to spread farther
        map_settings.pollution.diffusion_ratio = 0.05
        map_settings.pollution.min_to_diffuse = 10
        map_settings.pollution.expected_max_per_chunk = 6000

        map_settings.enemy_evolution.enabled = true
        map_settings.enemy_evolution.time_factor = 0.000016
        map_settings.enemy_evolution.pollution_factor = 0.000006

        if game.evolution_factor < 0 then
            game.evolution_factor = 0
        end
    end
end)
