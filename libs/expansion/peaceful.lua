
local expansion = {  name = "Peaceful",
    			 color = { r = 0, g = 255, b = 10 },
    			 max_time = 20 * 60 * 60, 
    			 min_time = 10 * 60 * 60, 
    			 min_evo_factor = 0, 
    			 evo_modifier = 1 }
                 
function expansion:update_expansion_state()
    game.map_settings.enemy_expansion.enabled = false
end

function expansion:tick()
    -- slowly restore the max steps worked per tick back to 100 (decreases by 1 per second)
    if game.tick % 60 == 0 and game.map_settings.path_finder.max_steps_worked_per_tick > 100 then
        game.map_settings.path_finder.max_steps_worked_per_tick = game.map_settings.path_finder.max_steps_worked_per_tick - 1
    end
end

return expansion
