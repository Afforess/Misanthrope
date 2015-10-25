data:extend(
{
    {
        type = "technology",
        name = "biter-science",
        icon = "__base__/graphics/technology/turrets.png",
        prerequisites = {"military-3", "turrets"},
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
