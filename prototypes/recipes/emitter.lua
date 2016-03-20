data:extend(
{
    {
        type = "recipe",
        name = "biter-emitter",
        energy_required = 6,
        enabled = false,
        ingredients =
        {
            {"iron-gear-wheel", 5},
            {"steel-plate", 10},
            {"advanced-circuit", 4},
        },
        result = "biter-emitter"
    },
    {
        type = "recipe",
        name = "micro-biter-emitter",
        energy_required = 2,
        enabled = false,
        ingredients =
        {
            {"biter-emitter", 1},
            {"processing-unit", 10},
            {"steel-plate", 10},
        },
        result = "micro-biter-emitter"
    }
}
)
