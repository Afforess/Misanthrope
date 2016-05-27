data:extend({
    {
        type = "tree",
        name = "spawner-damaged",
        icon = "__Misanthrope__/graphics/null.png",
        flags = {"placeable-neutral", "not-on-map", "placeable-off-grid"},
        subgroup = "remnants",
        order = "a[remnants]",
        max_health = 1,
        selection_box = {{-0.0, -0.0}, {0.0, 0.0}},
        collision_box = {{-0.0, -0.0}, {0.0, 0.0}},
        collision_mask = {"object-layer"},
        pictures =
        {
            {
                filename = "__Misanthrope__/graphics/null.png",
                width = 32,
                height = 32,
            }
        }
    },
})
