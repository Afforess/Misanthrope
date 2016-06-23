require 'stdlib/event/event'
require 'stdlib/log/logger'
require 'stdlib/entity/entity'
require 'stdlib/area/position'
require 'stdlib/area/area'
require 'stdlib/table'
require 'stdlib/game'

Overmind = {stages = {}, tick_rates = {}}
Overmind.Logger = Logger.new("Misanthrope", "overmind", false)
local Log = function(str, ...) Overmind.Logger.log(string.format(str, ...)) end

Event.register(defines.events.on_tick, function(event)
    if not global.overmind then
        global.overmind = { tick_rate = 600, currency = 0, stage = 'setup', data = {}, chunks = {}, valuable_chunks = {}, surface = game.surfaces.nauvis, tracked_entities = {} }
    end
    if not (event.tick % global.overmind.tick_rate == 0) then return end

    -- accrue a tiny amount of currency due to the passage of time
    if event.tick % 600 == 0 then
        if not global.bases or #global.bases < 3 then
            global.overmind.currency = global.overmind.currency + 100
        else
            global.overmind.currency = global.overmind.currency + 10
        end
    end

    -- clear out any tracked entities that have expired their max_age
    if event.tick % Time.MINUTE == 0 then
        table.each(table.filter(global.overmind.tracked_entities, function(entity_data) return entity_data.max_age < event.tick end), function(entity_data)
            if entity_data.entity.valid then
                entity_data.entity.destroy()
            end
        end)
        global.overmind.tracked_entities = table.filter(global.overmind.tracked_entities, function(entity_data) return entity_data.entity.valid end)
    end

    local prev_stage = global.overmind.stage
    local data = global.overmind.data
    local stage = Overmind.stages[prev_stage](data)
    if data.reset then
        global.overmind.data = {}
    end
    global.overmind.stage = stage
    if prev_stage ~= stage then
        Log("Updating stage from %s to %s", prev_stage, stage)
        global.overmind.tick_rate = Overmind.tick_rates[stage]
    end
end)

Overmind.tick_rates.setup = Time.SECOND * 10
Overmind.stages.setup = function(data)
    local chunks = global.overmind.chunks
    for chunk in game.surfaces.nauvis.get_chunks() do
        table.insert(chunks, chunk)
    end
    Log("Found %d chunks to scan", #chunks)
    return 'scan_chunk'
end

Overmind.tick_rates.decide = Time.SECOND * 10
Overmind.stages.decide = function(data)
    if #global.overmind.valuable_chunks > 0 then
        Log("Overmind currency: %d", math.floor(global.overmind.currency))
        if global.overmind.currency > 10000 and math.random(100) > 50 then
            global.overmind.currency = global.overmind.currency - 10000
            return 'spread_spawner'
        end

        if global.overmind.currency > 3000 and math.random(100) > 90 then
            global.overmind.currency = global.overmind.currency - 3000
            return 'spawn_biters'
        end

        return 'decide'
    end
    return 'setup'
end

Overmind.tick_rates.spawn_biters = Time.MINUTE / 4
Overmind.stages.spawn_biters = function(data)
    Log("Attempting to spawn biters, total valuable chunks: %d", #global.overmind.valuable_chunks)
    local spawnable_chunks = table.filter(global.overmind.valuable_chunks, function(data) return data.best_target ~= nil end)
    table.sort(spawnable_chunks, function(a, b)
        return b.value < a.value
    end)
    if #spawnable_chunks == 0 then
        return 'decide'
    end

    local chunk_data = spawnable_chunks[1]
    local chunk = chunk_data.chunk
    global.overmind.valuable_chunks = table.filter(global.overmind.valuable_chunks, function(data) return data.chunk.x ~= chunk.x and data.chunk.y ~= chunk.y end)
    Log("Choose chunk %s to spawn units on, remaining valuable chunks: %d", serpent.line(chunk), #global.overmind.valuable_chunks)

    local area = Chunk.to_area(chunk)
    local chunk_center = Area.center(area)
    local surface = global.overmind.surface

    if surface.count_entities_filtered({area = Area.expand(area, 32 * 4.5), force = game.forces.player}) > 0 then
        Log("Chunk %s had player entities within 4 chunks", serpent.line(chunk))
        return 'decide'
    end
    if surface.count_entities_filtered({type = 'unit-spawner', area = Area.expand(area, 32 * 4), force = game.forces.enemy}) > 0 then
        Log("Chunk %s had biter spawners within 4 chunks", serpent.line(chunk))
        return 'decide'
    end

    local max_age = game.tick + Time.MINUTE * 10
    local attack_group_size = math.floor(30 + game.evolution_factor / 0.025)
    local tracked_entities = global.overmind.tracked_entities
    local biters = {}
    local all_units = {'behemoth-biter', 'behemoth-spitter', 'big-biter', 'big-spitter', 'medium-biter', 'medium-spitter', 'small-spitter', 'small-biter'}
    local unit_count = 0
    for i = 1, attack_group_size do
        for _, unit_name in pairs(all_units) do
            local odds = 100 * Biters.unit_odds(unit_name)
            if odds > 0 and odds > math.random(100) then
                local spawn_pos = surface.find_non_colliding_position(unit_name, chunk_center, 12, 0.5)
                if spawn_pos then
                    local entity = surface.create_entity({name = unit_name, position = spawn_pos, force = 'enemy'})
                    if entity then
                        table.insert(biters, entity)
                        table.insert(tracked_entities, {entity = entity, max_age = max_age})
                        unit_count = unit_count + 1
                    end
                end
            end
        end
    end
    Log("Spawned %d units at chunk %s, to attack %s", unit_count, serpent.line(chunk), serpent.line(chunk_data.best_target))
    if #biters > 0 then
        local unit_group = surface.create_unit_group({position = biters[1].position, force = 'enemy'})
        for _, biter in pairs(biters) do
            unit_group.add_member(biter)
        end
        local cmd = {type = defines.command.attack_area, destination = Area.center(Chunk.to_area(chunk_data.best_target.chunk)), radius = 12}
        Log("Attack command: %s", serpent.line(cmd))
        unit_group.set_command(cmd)
        unit_group.start_moving()
    end

    return 'decide'
end

Overmind.tick_rates.spread_spawner = Time.MINUTE
Overmind.stages.spread_spawner = function(data)
    Log("Attempting to spread a spawner, total valuable chunks: %d", #global.overmind.valuable_chunks)
    local spawnable_chunks = table.filter(global.overmind.valuable_chunks, function(data) return data.spawn end)
    table.sort(spawnable_chunks, function(a, b)
        return b.value < a.value
    end)
    if #spawnable_chunks == 0 then
        return 'decide'
    end

    local chunk_data = spawnable_chunks[1]
    local chunk = chunk_data.chunk
    global.overmind.valuable_chunks = table.filter(global.overmind.valuable_chunks, function(data) return data.chunk.x ~= chunk.x and data.chunk.y ~= chunk.y end)
    Log("Choose chunk %s to spawn a new base, remaining valuable chunks: %d", serpent.line(chunk), #global.overmind.valuable_chunks)

    local surface = global.overmind.surface
    local area = Chunk.to_area(chunk)
    if surface.count_entities_filtered({area = Area.expand(area, 32 * 4.5), force = game.forces.player}) > 0 then
        Log("Chunk %s had player entities within 4 chunks", serpent.line(chunk))
        return 'decide'
    end
    if surface.count_entities_filtered({type = 'unit-spawner', area = Area.expand(area, 32 * 4), force = game.forces.enemy}) > 0 then
        Log("Chunk %s had biter spawners within 4 chunks", serpent.line(chunk))
        return 'decide'
    end

    local chunk_center = Area.center(area)
    local pos = surface.find_non_colliding_position('biter-spawner', chunk_center, 16, 1)
    if pos and Area.inside(area, pos) then
        local queen = surface.create_entity({name = 'biter-spawner', position = pos, direction = math.random(7)})
        local base = BiterBase.discover(queen)
        Log("Successfully spawned a new base: %s", BiterBase.tostring(base))
    else
        Log("Unable to spawn new base at chunk %s", serpent.line(chunk))
    end

    return 'decide'
end

Overmind.tick_rates.scan_chunk = 6
Overmind.stages.scan_chunk = function(data)
    if #global.overmind.chunks == 0 then
        return 'decide'
    end
    if #global.overmind.chunks % 100 == 0 then
        Log("Currently %d chunks in queue to be scanned", #global.overmind.chunks)
    end
    local chunk = table.remove(global.overmind.chunks, 1)
    local surface = global.overmind.surface

    local area = Chunk.to_area(chunk)
    local chunk_center = Area.center(area)

    if surface.count_entities_filtered({area = Area.expand(area, 32 * 4.5), force = game.forces.player}) > 0 then
        Log("Chunk %s had player entities within 4 chunks", serpent.line(chunk))
        return 'scan_chunk'
    end
    if surface.count_entities_filtered({type = 'unit-spawner', area = Area.expand(area, 32 * 4), force = game.forces.enemy}) > 0 then
        Log("Chunk %s had biter spawners within 4 chunks", serpent.line(chunk))
        return 'scan_chunk'
    end

    local pos = surface.find_non_colliding_position('biter-spawner', chunk_center, 16, 1)
    if not pos or not Area.inside(area, pos) then
        local pos = surface.find_non_colliding_position('medium-biter', chunk_center, 16, 1)
        if not pos or not Area.inside(area, pos) then
            Log("Chunk %s had no suitable location for spawner or biter", serpent.line(chunk))
            return 'scan_chunk'
        else
            Log("Chunk %s had no suitable location for spawner, but may support spawning biters", serpent.line(chunk))
            data.chunk = chunk
            data.adjacent = {}
            data.spawn = false
            data.nearby_bases = 0
            data.value = 0
            data.best = { value = 0, chunk = nil }
            for x, y in Area.iterate(Position.expand_to_area(chunk, 7)) do
                table.insert(data.adjacent, {x = x, y = y})
            end
            return 'evaluate_base'
        end
    end
    Log("Chunk %s had a suitable location for spawner", serpent.line(chunk))
    data.chunk = chunk
    data.adjacent = {}
    data.spawn = true
    data.nearby_bases = 0
    data.value = 0
    data.best = { value = 0, chunk = nil }
    for x, y in Area.iterate(Position.expand_to_area(chunk, 13)) do
        table.insert(data.adjacent, {x = x, y = y})
    end

    return 'evaluate_base'
end

Overmind.tick_rates.evaluate_base = 1
Overmind.stages.evaluate_base = function(data)
    if #data.adjacent == 0 then
        local value = math.floor(data.value)
        local nearby_bases = data.nearby_bases
        value = (value * 6) / (1 + nearby_bases)
        if value > 1000 then
            Log("Finished evaluating chunk %s, its value is %d", serpent.line(data.chunk), value)
            table.insert(global.overmind.valuable_chunks, { chunk = data.chunk, value = value, spawn = data.spawn, best_target = data.best })
        else
            --Log("Finished evaluating chunk %s, its value was too low (%d)", serpent.line(data.chunk), value)
        end
        data.reset = true
        return 'scan_chunk'
    end

    local surface = global.overmind.surface
    local adjacent_chunks = data.adjacent
    local limit = math.max(1, #adjacent_chunks - 50)
    for i = #adjacent_chunks, limit, -1 do
        local adj_chunk = adjacent_chunks[i]
        adjacent_chunks[i] = nil
        if adj_chunk then
            local chunk_data = Chunk.get_data(surface, adj_chunk)
            if chunk_data then
                if chunk_data.player_value then
                    data.value = data.value + chunk_data.player_value

                    if chunk_data.player_value > data.best.value then
                        data.best.value = chunk_data.player_value
                        data.best.chunk = adj_chunk
                    end
                end
                if chunk_data.base then
                    if chunk_data.base.valid then
                        data.nearby_bases = data.nearby_bases + 1
                    else
                        chunk_data.base = nil
                        -- remove chunk data if no entries remain
                        if next(chunk_data) == nil then
                            Chunk.set_data(surface, adj_chunk, nil)
                        end
                    end
                end
            end
        end
    end
    return 'evaluate_base'
end
