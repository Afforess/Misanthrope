
data:extend({
    {
    type = "radar",
    name = "power-short",
    icon = "__base__/graphics/icons/small-lamp.png",
    order="e-a-b",
    max_health = 0,
    corpse = "small-remnants",
    collision_box = {{-0.0, -0.0}, {0.0, 0.0}},
    selection_box = {{-0.0, -0.0}, {0.0, 0.0}},
    energy_source =
    {
      type = "electric",
      drain = "1000000kW", -- 1000 mW
      usage_priority = "primary-input"
    },
    energy_usage = "1000000KW",
    energy_per_sector = "1000MJ",
    max_distance_of_sector_revealed = 0,
    max_distance_of_nearby_sector_revealed = 0,
    energy_per_nearby_scan = "1000MJ",
    pictures =
    {
      filename = "__base__/graphics/entity/radar/radar.png",
      priority = "low",
      width = 0,
      height = 0,
      apply_projection = false,
      direction_count = 64,
      line_length = 8,
      shift = {0.875, -0.34375}
    },
  }
})
