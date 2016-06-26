require 'stdlib/event/event'
require 'stdlib/area/position'
require 'stdlib/area/area'
require 'stdlib/area/tile'

Event.register(defines.events.on_entity_died, function(event)
    local entity = event.entity
    local max_health = entity.prototype.max_health
    local position = Tile.from_position(entity.position)
    local surface = entity.surface

    local radius = math.floor(math.min(32, math.max(5, math.sqrt(max_health))))
    local area = Position.expand_to_area(position, radius)
    for x, y in Area.iterate(area) do
        local pos = {x = x, y = y}
        local dist_squared = Position.distance_squared(position, pos)
        local delta = math.min(max_health, math.floor(max_health / math.pow(dist_squared, 0.25)))
        if delta > 1 then
            local data = Tile.get_data(surface, pos, {})
            if not data.scent then
                 data.scent = delta
            else
                data.scent = data.scent + delta
            end
        end
    end
end)
