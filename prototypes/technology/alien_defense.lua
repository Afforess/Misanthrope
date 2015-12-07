data:extend(
{
    {
        type = "technology",
        name = "alien_defense",
        icon = "__Misanthrope__/graphics/biohazard.png",
        icon_size = 128,
        prerequisites = {"military-3", "turrets"},
        effects =
        {
            {
                type = "unlock-recipe",
                recipe = "biter-emitter"
            }
        },
        unit =
        {
            count = 100,
            ingredients =
            {
                {"science-pack-1", 2},
                {"science-pack-2", 1},
                {"science-pack-3", 1}
            },
            time = 50
        },
        upgrade = true,
        order = "e-l-a"
    }
})
