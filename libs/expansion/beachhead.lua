
local expansion = { name = "Beachhead", 
				   color = { r = 255, g = 0, b = 0 },
				   max_time = 5 * 60 * 60,
				   min_time = 4 * 60 * 60, 
				   min_evo_factor = 0.85, 
				   evo_modifier = 0.75 }

function expansion:update_expansion_state()
	game.map_settings.enemy_expansion.enabled = true
	game.map_settings.enemy_expansion.min_base_spacing = 2
	game.map_settings.enemy_expansion.max_expansion_distance = 2
	game.map_settings.enemy_expansion.min_player_base_distance = 0
	game.map_settings.enemy_expansion.settler_group_min_size = 30
	game.map_settings.enemy_expansion.settler_group_max_size = 75
	game.map_settings.enemy_expansion.min_expansion_cooldown = 5 * 60
	game.map_settings.enemy_expansion.max_expansion_cooldown = 20 * 60

	game.map_settings.unit_group.max_group_radius = 60
	game.map_settings.unit_group.max_member_speedup_when_behind = 4
end

return expansion
