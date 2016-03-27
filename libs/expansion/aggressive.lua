
local expansion = { name = "Aggressive Expansion", 
				    color = { r = 255, g = 155, b = 0 },
				    max_time = 7 * 60 * 60, 
				    min_time = 4 * 60 * 60, 
				    min_evo_factor = 0.50, 
				    evo_modifier = 0.96,
					minimum_attack_value = 0,
					min_biter_attack_group = 50,
					min_biter_attack_chunk_distance = 12,
					min_biter_search_distance = 96}

function expansion:update_expansion_state()
	game.map_settings.enemy_expansion.enabled = true
	game.map_settings.enemy_expansion.min_base_spacing = 3
	game.map_settings.enemy_expansion.max_expansion_distance = 8
	game.map_settings.enemy_expansion.min_player_base_distance = 6
	game.map_settings.enemy_expansion.settler_group_min_size = 15
	game.map_settings.enemy_expansion.settler_group_max_size = 30
	game.map_settings.enemy_expansion.min_expansion_cooldown = 5 * 60
	game.map_settings.enemy_expansion.max_expansion_cooldown = 25 * 60

	game.map_settings.unit_group.max_member_speedup_when_behind = 2

end

return expansion
