require 'stdlib/event/event'
require 'stdlib/log/logger'
require 'stdlib/entity/entity'
require 'stdlib/area/position'
require 'stdlib/area/area'
require 'stdlib/table'
require 'stdlib/game'

BiterBase = {}
BiterBase.Logger = Logger.new("Misanthrope", "biter_base", DEBUG_MODE)
local Log = function(str, ...) BiterBase.Logger.log(string.format(str, ...)) end

--- Creates a biter base from spawner entity
function BiterBase.discover(entity)
    local pos = entity.position

    -- initialize biter base data structure
    local base = { queen = entity, hives = {}, worms = {}, currency = 0, next_tick = game.tick + math.random(300, 1000), valid = true}
    table.insert(global.bases, base)
    Entity.set_data(entity, {base = base})
    Log("Created new biter base at (%d, %d)", pos.x, pos.y)

    -- scan for nearby unclaimed hives
    local surface = entity.surface
    local nearby_area = Position.expand_to_area(pos, 10)
    local spawners = surface.find_entities_filtered({ area = nearby_area, type = 'unit-spawner', force = entity.force})
    for _, spawner in pairs(spawners) do
        if spawner ~= entity then
            -- associate each of these entities with the base
            Entity.set_data(spawner, {base = base})
            table.insert(base.hives, spawner)
        end
    end
    Log("Discovered {%d} hives near the new biter base at (%d, %d)", #base.hives, pos.x, pos.y)

    -- scan for nearby unclaimed worms
    local worms = surface.find_entities_filtered({ area = nearby_area, type = 'turret', force = entity.force})
    for _, worm in pairs(worms) do
        -- associate each of these entities with the base
        Entity.set_data(worm, {base = base})
        table.insert(base.worms, worm)
    end
    Log("Discovered {%d} worms near the new biter base at (%d, %d)", #base.worms, pos.x, pos.y)

    -- destroy hives too close, but too far to be useful
    local reclaimed_evo = 0
    local spawners = surface.find_entities_filtered({ area = Position.expand_to_area(pos, 32), type = 'unit-spawner', force = entity.force})
    for _, spawner in pairs(spawners) do
        if not Area.inside(nearby_area, spawner.position) then
            spawner.destroy()
            reclaimed_evo = reclaimed_evo + 0.003
        end
    end
    Log("Destroyed {%d} hives near the new biter base at (%d, %d)", math.floor(reclaimed_evo / 0.003), pos.x, pos.y)
    game.evolution_factor = math.min(1, game.evolution_factor + reclaimed_evo)
end

function BiterBase.on_queen_death(base)
    local pos = base.queen.position

    Log("Biter Base queen at (%d, %d) died", pos.x, pos.y)
    local hives = #table.filter(base.hives, Game.VALID_FILTER)
    if hives == 0 then
        Log("Biter Base at (%d, %d) has no remaining hives, and no queen. ", pos.x, pos.y)
        base.valid = false
        global.bases = table.filter(global.bases, Game.VALID_FILTER)
    else
        local new_queen = table.remove(base.hives, 1)
        base.queen = new_queen
        Log("Biter Base at (%d, %d) has appointed a new queen at (%d, %d)", pos.x, pos.y, new_queen.position.x, new_queen.position.y)
    end
end

function BiterBase.tick(base)

end

--- Sets up any events needed at the start/load of each game
function BiterBase.setup(base)

end

Event.register(defines.events.on_tick, function(event)
    local tick = event.tick
    if tick % 60 == 0 then
        for i = 1, #global.bases do
            local base = global.bases[i]
            base.currency = base.currency + 1 + #base.hives
            if base.next_tick < tick then
                BiterBase.tick(base)
            end
        end
    end
end)

Event.register(defines.events.on_chunk_generated, function(event)
    local area = event.area
    local surface = event.surface

    -- Run one tick later to ensure compatibility with mods that are doing stuff in on_chunk_generated
    Event.register(defines.events.on_tick, function(event)
        Log("Chunk generated, checking area {%s} for spawners", serpent.line(area, {comment=false}))
        for _, spawner in pairs(surface.find_entities_filtered({area = area, type = 'unit-spawner', force = game.forces.enemy})) do
            if spawner.valid then
                local data = Entity.get_data(spawner)
                if not data or not data.base then
                    BiterBase.discover(spawner)
                end
            end
        end

        Event.remove(defines.events.on_tick, event._handler)
    end)
end)

Event.register(defines.events.on_entity_died, function(event)
    local entity = event.entity
    if entity.type == 'unit-spawner' then
        local data = Entity.set_data(entity, nil)
        if data and data.base then
            local base = data.base
            if base.queen == entity then
                BiterBase.on_queen_death(base)
            else
                for i = #base.hives, 1, -1 do
                    if base.hives[i] == entity then
                        table.remove(base.hives, i)
                    end
                end
            end
        end
    end
end)
