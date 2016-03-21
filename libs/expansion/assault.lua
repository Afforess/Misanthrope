
local expansion = { name = "Assault",
				    color = { r = 255, g = 50, b = 0 },
					max_time = 5 * 60 * 60, 
					min_time = 3 * 60 * 60, 
					min_evo_factor = 0.70, 
					evo_modifier = 0.90,
					minimum_attack_value = 0,
					min_biter_attack_group = 75,
					min_biter_search_distance = 128}

function expansion:update_expansion_state()
	game.map_settings.enemy_expansion.enabled = true
	game.map_settings.enemy_expansion.min_base_spacing = 1
	game.map_settings.enemy_expansion.max_expansion_distance = 10
	game.map_settings.enemy_expansion.min_player_base_distance = 3
	game.map_settings.enemy_expansion.settler_group_min_size = 20
	game.map_settings.enemy_expansion.settler_group_max_size = 60
	game.map_settings.enemy_expansion.min_expansion_cooldown = 5 * 60
	game.map_settings.enemy_expansion.max_expansion_cooldown = 20 * 60

	game.map_settings.unit_group.max_group_radius = 60
	game.map_settings.unit_group.max_member_speedup_when_behind = 3

end

return expansion
