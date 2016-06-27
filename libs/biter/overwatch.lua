require 'stdlib/event/event'
require 'stdlib/log/logger'
require 'stdlib/entity/entity'
require 'stdlib/area/position'
require 'stdlib/area/area'
require 'stdlib/table'
require 'stdlib/game'

Overwatch = {stages = {}, tick_rates = {}}
Overwatch.Logger = Logger.new("Misanthrope", "overwatch", false)
local Log = function(str, ...) Overwatch.Logger.log(string.format(str, ...)) end

Event.register(defines.events.on_tick, function(event)
    if not global.overwatch then
        global.overwatch = { tick_rate = 600, stage = 'setup', data = {}, chunks = {}, valuable_chunks = {}, surface = game.surfaces.nauvis}
    end
    if not (event.tick % global.overwatch.tick_rate == 0) then return end

    local prev_stage = global.overwatch.stage
    local data = global.overwatch.data
    local stage = Overwatch.stages[prev_stage](data)
    if data.reset then
        global.overwatch.data = {}
    end
    global.overwatch.stage = stage
    if prev_stage ~= stage then
        Log("Updating stage from %s to %s", prev_stage, stage)
        global.overwatch.tick_rate = Overwatch.tick_rates[stage]
    end
end)

Overwatch.tick_rates.setup = Time.SECOND * 10
Overwatch.stages.setup = function(data)
    local chunks = global.overwatch.chunks
    for chunk in global.overwatch.surface.get_chunks() do
        table.insert(chunks, chunk)
    end
    Log("Found %d chunks to scan", #chunks)
    return 'scan_chunk'
end

Overwatch.tick_rates.decide = Time.SECOND * 10
Overwatch.stages.decide = function(data)
    if #global.overwatch.valuable_chunks > 100 then
        return 'decide'
    end
    return 'setup'
end

Overwatch.tick_rates.scan_chunk = 60
Overwatch.stages.scan_chunk = function(data)
    if #global.overwatch.chunks == 0 then
        return 'decide'
    end
    if #global.overwatch.chunks % 100 == 0 then
        Log("Currently %d chunks in queue to be scanned", #global.overwatch.chunks)
    end
    local chunk = table.remove(global.overwatch.chunks, math.random(1, #global.overwatch.chunks))
    local surface = global.overwatch.surface

    local area = Chunk.to_area(chunk)
    local chunk_center = Area.center(area)

    if surface.count_entities_filtered({type = 'unit-spawner', area = Area.expand(area, 64), force = game.forces.enemy}) > 0 then
        Log("Chunk %s had biter spawners within 2 chunks", serpent.line(chunk))
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
            return 'analyze_base'
        end
    end
    Log("Chunk %s had a suitable location for spawner", serpent.line(chunk))
    data.chunk = chunk
    data.adjacent = {}
    data.spawn = true
    data.nearby_bases = 0
    data.value = 0
    data.best = { value = 0, chunk = nil }
    for x, y in Area.iterate(Position.expand_to_area(chunk, 15)) do
        table.insert(data.adjacent, {x = x, y = y})
    end

    return 'analyze_base'
end


Overwatch.tick_rates.evaluate_base = 10
Overwatch.stages.evaluate_base = function(data)
    local value = math.floor(data.value)
    local nearby_bases = data.nearby_bases
    value = (value * 6) / (1 + nearby_bases)

    local surface = global.overwatch.surface
    local area = Chunk.to_area(data.chunk)
    local player_entities = surface.count_entities_filtered({area = Area.expand(area, 32 * 5), force = game.forces.player})
    if player_entities > 0 then
        value = value / (math.sqrt(player_entities))
    end

    value = math.floor(value)
    if value > 1000 then
        Log("Finished evaluating chunk %s, its value is %d", serpent.line(data.chunk), value)
        table.insert(global.overwatch.valuable_chunks, { chunk = data.chunk, value = value, spawn = data.spawn, best_target = data.best })
    else
        Log("Finished evaluating chunk %s, value too low, its value is %d", serpent.line(data.chunk), value)
    end
    data.reset = true
    return 'scan_chunk'
end

Overwatch.tick_rates.analyze_base = 3
Overwatch.stages.analyze_base = function(data)
    -- finished evaluation
    if #data.adjacent == 0 then
        return 'evaluate_base'
    end

    local surface = global.overwatch.surface
    local adjacent_chunks = data.adjacent
    local limit = math.max(1, #adjacent_chunks - 25)
    for i = #adjacent_chunks, limit, -1 do
        local adj_chunk = adjacent_chunks[i]
        adjacent_chunks[i] = nil
        if adj_chunk then
            local chunk_data = Chunk.get_data(surface, adj_chunk)
            if chunk_data then
                if chunk_data.player_value then

                    -- don't track negative value chunks
                    data.value = data.value + math.max(0, chunk_data.player_value)

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
    return 'analyze_base'
end
