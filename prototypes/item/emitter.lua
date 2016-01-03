data:extend({
	{
		type = "item",
		name = "biter-emitter",
        icon = "__Misanthrope__/graphics/emitter-icon.png",
		flags = {"goes-to-quickbar"},
        subgroup = "defensive-structure",
        order = "c-c",
		place_result = "biter-emitter",
		enable = false,
		stack_size = 4
	},
	{
	    type = "item",
	    name = "micro-biter-emitter",
		icon = "__Misanthrope__/graphics/micro-emitter-icon.png",
	    placed_as_equipment_result = "micro-biter-emitter",
	    flags = {"goes-to-main-inventory"},
	    subgroup = "equipment",
	    order = "e[robotics]-a[micro-biter-emitter]",
		enable = false,
	    stack_size = 1
	},
})
