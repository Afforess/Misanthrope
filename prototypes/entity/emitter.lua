data:extend({
    {
        type = "radar",
        name = "biter-emitter",
        icon = "__Misanthrope__/graphics/emitter-icon.png",
        flags = {"placeable-neutral", "placeable-player", "player-creation"},   
        minable = {hardness = 0.8, mining_time = 3, result = "biter-emitter"},
        max_health = 250,
        corpse = "small-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-0.29, -0.29}, {0.29, 0.29}},
        selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
        energy_per_sector = "1MJ",
        max_distance_of_nearby_sector_revealed = 1,
        max_distance_of_sector_revealed = 1,
        energy_per_nearby_scan = "25kJ",
        energy_source =
        {
            type = "electric",
            usage_priority = "secondary-input"
        },
        energy_usage = "50kW",
        pictures =
        {
            filename = "__Misanthrope__/graphics/emitter.png",
            priority = "high",
            width = 60,
            height = 60,
            axially_symmetrical = false,
            apply_projection = false,
            direction_count = 25,
            line_length = 5,
            shift = {0.425, -0.5},
        },
    }
})
