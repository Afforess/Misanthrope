
local Harrassment = {stages = {}}
local Log = function(str, ...) BiterBase.LogAI("[Harrassment] " .. str, ...) end

Harrassment.search_radius = 14
Harrassment.search_queue = {}
for dx, dy in Area.spiral_iterate(Position.expand_to_area({0, 0}, Harrassment.search_radius)) do
    table.insert(Harrassment.search_queue, {x = dx, y = dy})
end
Harrassment.search_queue_size = #Harrassment.search_queue

function Harrassment.search_queue_chunk(base, data)
    local idx = data.search_idx
    local center = Chunk.from_position(base.queen.position)
    local delta_pos = Harrassment.search_queue[idx]
    return { x = center.x + delta_pos.x, y = center.y + delta_pos.y }
end

Harrassment.stages.attacking = function(base, data)
    return 'attacking'
end

Harrassment.stages.spawning = function(base, data)
    local command = {type = defines.command.attack_area, destination = data.target_pos, radius = 8}
    local surface = base.queen.surface
    for _, hive in pairs(base:all_hives()) do
        local biter = Biters.spawn_biter(base, surface, hive)
        if biter then
            biter.set_command(command)
        end
    end
    base.entities = table.filter(base.entities, Game.VALID_FILTER)
    return 'spawning'
end

Harrassment.stages.search = function(base, data)
    if data.search_idx > Harrassment.search_queue_size then
        if not data.worst_candidate.chunk_pos then
            return 'fail'
        end
        data.end_tick = game.tick + (Time.MINUTE * math.random(3,7))
        data.target_pos = Area.center(Chunk.to_area(data.worst_candidate.chunk_pos))
        return 'spawning'
    end
    local chunk_pos = Harrassment.search_queue_chunk(base, data)

    local chunk_value = World.get_chunk_value(base.queen.surface, chunk_pos)
    if chunk_value < 0 then
        local dist = Position.manhattan_distance(chunk_pos, data.start_chunk)

        value = (chunk_value * chunk_value) / ((1 + dist) * (1 + dist))
        if data.worst_candidate.value == nil or data.worst_candidate.value < value then
            data.worst_candidate = { chunk_pos = chunk_pos, value = math.floor(value) }
        end
    end

    data.search_idx = data.search_idx + 1
    return 'search'
end

Harrassment.stages.setup = function(base, data)
    data.search_idx = 1
    data.worst_candidate = { chunk_pos = nil, value = nil }
    return 'search'
end

function Harrassment.tick(base, data)
    if not data.stage then
        data.stage = 'setup'
    end
    local prev_stage = data.stage
    data.stage = Harrassment.stages[data.stage](base, data)
    if prev_stage ~= data.stage then
        Log("Updating stage from %s to %s", base, prev_stage, data.stage)
    end
    return true
end

function Harrassment.is_expired(base, data)
    if data.stage == 'fail' or data.stage == 'success' then
        return true
    end
    if data.end_tick then
        return game.tick > data.end_tick
    end
    return false
end

return Harrassment
