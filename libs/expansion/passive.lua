
local expansion = { name = "Passive Expansion",
				   color = { r = 255, g = 255, b = 0 },
				   max_time = 10 * 60 * 60,
				   min_time = 5 * 60 * 60, 
				   min_evo_factor = 0.30, 
				   evo_modifier = 0.95 }

function expansion:update_expansion_state()
	game.map_settings.enemy_expansion.enabled = true
	game.map_settings.enemy_expansion.min_base_spacing = 4
	game.map_settings.enemy_expansion.max_expansion_distance = 6
	game.map_settings.enemy_expansion.min_player_base_distance = 10
	game.map_settings.enemy_expansion.settler_group_min_size = 4
	game.map_settings.enemy_expansion.settler_group_max_size = 8
	game.map_settings.enemy_expansion.min_expansion_cooldown = 10 * 60
	game.map_settings.enemy_expansion.max_expansion_cooldown = 30 * 60
end

return expansion
