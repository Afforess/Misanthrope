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
        global.overmind = { tick_rate = 600, currency = 0, stage = 'decide', data = {}, tracked_entities = {} }
    end
    if not (event.tick % global.overmind.tick_rate == 0) then return end

    -- accrue a tiny amount of currency due to the passage of time
    if event.tick % 600 == 0 then
        if not global.bases or #global.bases < 3 then
            global.overmind.currency = global.overmind.currency + 100
        elseif #global.bases < 50 then
            global.overmind.currency = global.overmind.currency + 10 + (50 - #global.bases)
        else
            global.overmind.currency = global.overmind.currency + 10
        end

        if game.evolution_factor < 0.1 then
            global.overmind.currency = math.floor(global.overmind.currency / 5)
        elseif game.evolution_factor < 0.2 then
            global.overmind.currency = math.floor(global.overmind.currency / 2)
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

Overmind.tick_rates.decide = 600
Overmind.stages.decide = function(data)
    Log("Overmind currency: %d, Valuable Chunks: %d", math.floor(global.overmind.currency), #global.overwatch.valuable_chunks)
    if #global.overwatch.valuable_chunks > 0 then
        if global.overmind.currency > 10000 then

            if global.overmind.currency > 100000 then
                if math.random(100) < 75 then
                    Log("Overmind selects spread early and expensive hive spawner")
                    global.overmind.currency = global.overmind.currency - 25000
                    return 'fast_spread_spawner'
                end
            end

            if math.random(100) < 50 then
                Log("Overmind selects early biter spawn")
                global.overmind.currency = global.overmind.currency - 3000
                return 'spawn_biters'
            end

            -- Early
            if math.random(100) < 33 and game.evolution_factor < 0.33 then
                Log("Overmind selects early evolution factor boost")
                global.overmind.currency = global.overmind.currency - 10000
                data.extra_factor = 0.0000125
                data.iterations = 3200
                return 'increase_evolution_factor'
            end

            if math.random(100) < 25 then
                Log("Overmind selects spread hive spawner")
                global.overmind.currency = global.overmind.currency - 10000
                return 'spread_spawner'
            end

            if math.random(100) < 25 and global.overmind.currency > 50000 then
                Log("Overmind selects donate currency to poor")
                global.overmind.currency = global.overmind.currency - 10000
                return 'donate_currency_to_poor'
            end

            if math.random(100) < 33 and game.evolution_factor < 0.8 then
                Log("Overmind selects late evolution factor boost")
                global.overmind.currency = global.overmind.currency - 10000
                data.extra_factor = 0.0000125
                data.iterations = 3200
                return 'increase_evolution_factor'
            end

        end
    end
    return 'decide'
end

Overmind.tick_rates.donate_currency_to_poor = Time.MINUTE * 1
Overmind.stages.donate_currency_to_poor = function(data)
    if not data.iterations then
        data.iterations = 1
    end
    if global.overmind.currency > 10000 then
        local start_currency = global.overmind.currency
        table.each(table.filter(global.bases, Game.VALID_FILTER), function(base)
            if base.currency.amt < 6000 and global.overmind.currency > 1000 then
                base.currency.amt = base.currency.amt + 1000
                global.overmind.currency = global.overmind.currency - 1000
            end
        end)
        data.iterations = data.iterations + 1
        if data.iterations > 10 then
            return 'decide'
        end
        -- successfully found donation targets
        if start_currency > global.overmind.currency then
            return 'donate_currency_to_poor'
        end
    end

    return 'decide'
end

Overmind.tick_rates.increase_evolution_factor = 10
Overmind.stages.increase_evolution_factor = function(data)
    if data.iterations > 0 then
        data.iterations = data.iterations - 1
        game.evolution_factor = game.evolution_factor + data.extra_factor
        return 'increase_evolution_factor'
    end

    data.reset = true
    return 'decide'
end

Overmind.tick_rates.spawn_biters = Time.MINUTE
Overmind.stages.spawn_biters = function(data)
    Log("Attempting to spawn biters, total valuable chunks: %d", #global.overwatch.valuable_chunks)
    local spawnable_chunks = table.filter(global.overwatch.valuable_chunks, function(data) return data.best_target ~= nil end)
    table.sort(spawnable_chunks, function(a, b)
        return b.value < a.value
    end)
    if #spawnable_chunks == 0 then
        return 'decide'
    end

    local chunk_data = spawnable_chunks[1]
    local chunk = chunk_data.chunk
    global.overwatch.valuable_chunks = table.filter(global.overwatch.valuable_chunks, function(data) return data.chunk.x ~= chunk.x and data.chunk.y ~= chunk.y end)
    Log("Choose chunk %s to spawn units on, remaining valuable chunks: %d", Chunk.to_string(chunk), #global.overwatch.valuable_chunks)

    local area = Chunk.to_area(chunk)
    local chunk_center = Area.center(area)
    local surface = global.overwatch.surface
    if surface.count_entities_filtered({area = Area.expand(area, 32 * 2), force = game.forces.player}) > 16 then
        Log("Chunk %s had > 16 player entities within 2 chunks", Chunk.to_string(chunk))
        return 'decide'
    end
    if surface.count_entities_filtered({area = Area.expand(area, 32 * 4), force = game.forces.player}) > 100 then
        Log("Chunk %s had > 100 player entities within 4 chunks", Chunk.to_string(chunk))
        return 'decide'
    end
    if surface.count_entities_filtered({type = 'unit-spawner', area = Area.expand(area, 64), force = game.forces.enemy}) > 0 then
        Log("Chunk %s had biter spawners within 2 chunks", Chunk.to_string(chunk))
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
    Log("Spawned %d units at chunk %s, to attack %s", unit_count, Chunk.to_string(chunk), serpent.line(chunk_data.best_target))
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

Overmind.tick_rates.spread_spawner = Time.MINUTE * 4
Overmind.stages.spread_spawner = function(data)
    Log("Attempting to spread a spawner, total valuable chunks: %d", #global.overwatch.valuable_chunks)
    local spawnable_chunks = table.filter(global.overwatch.valuable_chunks, function(data) return data.spawn end)
    table.sort(spawnable_chunks, function(a, b)
        return b.value < a.value
    end)
    if #spawnable_chunks == 0 then
        return 'decide'
    end

    local chunk_data = spawnable_chunks[1]
    local chunk = chunk_data.chunk
    global.overwatch.valuable_chunks = table.filter(global.overwatch.valuable_chunks, function(data) return data.chunk.x ~= chunk.x and data.chunk.y ~= chunk.y end)
    Log("Choose chunk %s to spawn a new base, remaining valuable chunks: %d", Chunk.to_string(chunk), #global.overwatch.valuable_chunks)

    local surface = global.overwatch.surface
    local area = Chunk.to_area(chunk)
    if surface.count_entities_filtered({area = Area.expand(area, 32 * 2), force = game.forces.player}) > 16 then
        Log("Chunk %s had > 16 player entities within 2 chunks", Chunk.to_string(chunk))
        return 'decide'
    end
    if surface.count_entities_filtered({area = Area.expand(area, 32 * 4), force = game.forces.player}) > 100 then
        Log("Chunk %s had > 100 player entities within 4 chunks", Chunk.to_string(chunk))
        return 'decide'
    end
    if surface.count_entities_filtered({type = 'unit-spawner', area = Area.expand(area, 64), force = game.forces.enemy}) > 0 then
        Log("Chunk %s had biter spawners within 2 chunks", Chunk.to_string(chunk))
        return 'decide'
    end

    local chunk_center = Area.center(area)
    local pos = surface.find_non_colliding_position('biter-spawner', chunk_center, 16, 1)
    if pos and Area.inside(area, pos) then
        local queen = surface.create_entity({name = 'biter-spawner', position = pos, direction = math.random(7)})
        local base = BiterBase.discover(queen)
        Log("Successfully spawned a new base: %s", BiterBase.tostring(base))
    else
        Log("Unable to spawn new base at chunk %s", Chunk.to_string(chunk))
    end

    return 'decide'
end

Overmind.tick_rates.fast_spread_spawner = Time.MINUTE / 6
Overmind.stages.fast_spread_spawner = Overmind.stages.spread_spawner
