
local expansion = { name = "Beachhead",
				   color = { r = 255, g = 0, b = 0 },
				   max_time = 5 * 60 * 60,
				   min_time = 4 * 60 * 60,
				   min_evo_factor = 0.85,
				   evo_modifier = 0.85,
				   minimum_attack_value = 0,
				   min_biter_attack_group = 50,
				   min_biter_attack_chunk_distance = 20,
				   min_biter_search_distance = 172,
				   compute_time = 20,
				   region_attack_chance = 70,
				   region_update_frequency = 30}

function expansion:update_expansion_state()
	game.map_settings.enemy_expansion.enabled = true
	game.peaceful_mode = false

	game.map_settings.enemy_expansion.min_base_spacing = 2
	game.map_settings.enemy_expansion.max_expansion_distance = 2
	game.map_settings.enemy_expansion.min_player_base_distance = 1

	game.map_settings.unit_group.max_group_radius = 60
	game.map_settings.unit_group.max_member_speedup_when_behind = 4
end

return expansion
