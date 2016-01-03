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
    },
    {
        type = "technology",
        name = "alien_defense-2",
        icon = "__Misanthrope__/graphics/biohazard.png",
        icon_size = 128,
        prerequisites = {"alien_defense"},
        effects =
        {
            {
                type = "unlock-recipe",
                recipe = "micro-biter-emitter"
            }
        },
        unit =
        {
            count = 50,
            ingredients =
            {
                {"science-pack-1", 4},
                {"science-pack-2", 4},
                {"science-pack-3", 2},
                {"alien-science-pack", 1}
            },
            time = 50
        },
        upgrade = true,
        order = "e-l-a"
    }
})
