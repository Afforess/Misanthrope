
local expansion = {  name = "Peaceful",
					 color = { r = 0, g = 255, b = 10 },
					 max_time = 15 * 60 * 60,
					 min_time = 5 * 60 * 60,
					 min_evo_factor = 0,
					 evo_modifier = 1,
					 minimum_attack_value = 10000,
					 min_biter_attack_group = 10,
					 min_biter_attack_chunk_distance = 1,
					 min_biter_search_distance = 16,
					 compute_time = 0,
					 region_attack_chance = 0,
					 region_update_frequency = 1200}

function expansion:update_expansion_state()
	game.map_settings.enemy_expansion.enabled = false
	game.peaceful_mode = true
end

function expansion:tick()
	-- slowly restore the max steps worked per tick back to 100 (decreases by 1 per second)
	if game.tick % 60 == 0 and game.map_settings.path_finder.max_steps_worked_per_tick > 100 then
		game.map_settings.path_finder.max_steps_worked_per_tick = game.map_settings.path_finder.max_steps_worked_per_tick - 1
	end
end

return expansion
