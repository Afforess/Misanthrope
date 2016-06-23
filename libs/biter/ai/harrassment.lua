
local Harrassment = {stages = {}}
local Log = function(str, ...) BiterBase.LogAI("[Harrassment] " .. str, ...) end

Harrassment.stages.attacking = function(base, data)
    return 'attacking'
end

Harrassment.stages.spawning = function(base, data)
    local command = {type = defines.command.attack_area, destination = data.target_pos, radius = 8}
    for _, hive in pairs(base:all_hives()) do
        local biter = Biters.spawn_biter(base, data.surface, hive)
        if biter then
            biter.set_command(command)
        end
    end
    return 'spawning'
end

Harrassment.stages.search = function(base, data)
    if data.search_idx > #data.search_queue then
        if not data.worst_candidate.chunk_pos then
            return 'fail'
        end
        data.end_tick = game.tick + (Time.MINUTE * math.random(3,7))
        data.surface = base.queen.surface
        data.target_pos = Area.center(Chunk.to_area(data.worst_candidate.chunk_pos))
        return 'spawning'
    end
    local chunk_pos = data.search_queue[data.search_idx]

    local chunk_data = Chunk.get_data(base.queen.surface, chunk_pos)
    if chunk_data and chunk_data.player_value and chunk_data.player_value < 0 then
        local dist = Position.manhattan_distance(chunk_pos, data.start_chunk)

        value = (chunk_data.player_value * chunk_data.player_value) / ((1 + dist) * (1 + dist))
        if data.worst_candidate.value == nil or data.worst_candidate.value < value then
            data.worst_candidate = { chunk_pos = chunk_pos, value = value }
        end
    end

    data.search_idx = data.search_idx + 1
    return 'search'
end

Harrassment.stages.setup = function(base, data)
    local chunk_pos = Chunk.from_position(base.queen.position)
    local search_area = Position.expand_to_area(chunk_pos, 12)
    data.start_chunk = chunk_pos
    data.search_queue = {}
    data.search_idx = 1
    data.worst_candidate = { chunk_pos = nil, value = nil }
    for x, y in Area.spiral_iterate(search_area) do
        table.insert(data.search_queue, {x = x, y = y})
    end
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
