
local expansion = { name = "Normal",
				    color = { r = 255, g = 255, b = 255 },
				    max_time = 15 * 60 * 60, 
				    min_time = 5 * 60 * 60, 
				    min_evo_factor = 0.15, 
				    evo_modifier = 1 }

function expansion:update_expansion_state()
    game.map_settings.enemy_expansion.enabled = true

    -- vanilla map settings
    game.map_settings.enemy_expansion.min_base_spacing = 3
    game.map_settings.enemy_expansion.max_expansion_distance = 7
    game.map_settings.enemy_expansion.min_player_base_distance = 3
    game.map_settings.enemy_expansion.settler_group_min_size = 5
    game.map_settings.enemy_expansion.settler_group_max_size = 20
    game.map_settings.enemy_expansion.min_expansion_cooldown = 5 * 3600
    game.map_settings.enemy_expansion.max_expansion_cooldown = 60 * 3600

    game.map_settings.unit_group.max_member_speedup_when_behind = 1.4
end

return expansion
