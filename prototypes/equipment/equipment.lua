data:extend(
{
	{
		type = "movement-bonus-equipment",
		name = "micro-biter-emitter",
		sprite =
		{
			filename = "__Misanthrope__/graphics/micro-emitter-icon.png",
			width = 32,
			height = 32,
			priority = "medium"
		},
		shape =
		{
			width = 1,
			height = 1,
			type = "full"
		},
		energy_source =
		{
			type = "electric",
			usage_priority = "secondary-input"
		},
		energy_consumption = "50kW",
		movement_bonus = 0,
		categories = {"armor"}
	}
}
)
