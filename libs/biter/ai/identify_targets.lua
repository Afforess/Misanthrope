require 'libs/pathfinding_engine'

local IdentifyTargets = {stages = {}}
local Log = function(str, ...) BiterBase.LogAI("[IdentifyTargets] " .. str, ...) end

IdentifyTargets.stages.setup = function(base, data)
    local chunk_pos = Chunk.from_position(base.queen.position)
    local search_area = Position.expand_to_area(chunk_pos, 15)
    data.start_chunk = chunk_pos
    data.search_queue = {}
    data.search_idx = 1
    data.candidates = {}
    data.path_finding = { idx = 1, path_id = -1}
    data.completed = false
    for x, y in Area.spiral_iterate(search_area) do
        table.insert(data.search_queue, {x = x, y = y})
    end
    return 'search'
end

IdentifyTargets.stages.search = function(base, data)
    if data.search_idx > #data.search_queue then
        return 'sort'
    end
    local chunk_pos = data.search_queue[data.search_idx]

    local chunk_data = Chunk.get_data(base.queen.surface, chunk_pos)
    if chunk_data and chunk_data.player_value and chunk_data.player_value > 0 then
        local dist = Position.manhattan_distance(chunk_pos, data.start_chunk)

        value = chunk_data.player_value / ((1 + dist) * (1 + dist))
        table.insert(data.candidates, { chunk_pos = chunk_pos, data = chunk_data, value = value})
    end

    data.search_idx = data.search_idx + 1
    return 'search'
end

IdentifyTargets.stages.sort = function(base, data)
    if #data.candidates == 0 then
        Log("No candidates, unable to identify any targets.", base)
        return 'fail'
    end
    table.sort(data.candidates, function(a, b)
        return b.value < a.value
    end)

    Log("All candidates: %s", base, serpent.block(data.candidates))

    return 'decide'
end

IdentifyTargets.stages.decide = function(base, data)
    local idx = math.random(#data.candidates)
    local choosen_candidate = data.candidates[idx]
    Log("Randomly chosen candidate was %s", base, serpent.line(choosen_candidate))
    base.target = { type = 'player_value', chunk_pos = choosen_candidate.chunk_pos, tick = game.tick}
    return 'success'
end

function IdentifyTargets.tick(base, data)
    if not data.stage then
        data.stage = 'setup'
    end
    local prev_stage = data.stage
    data.stage = IdentifyTargets.stages[data.stage](base, data)
    if prev_stage ~= data.stage then
        Log("Updating stage from %s to %s", base, prev_stage, data.stage)
    end
    return true
end

function IdentifyTargets.is_expired(base, data)
    if data.stage == 'fail' then
        Log("Failed to identify any targets", base)
        return true
    elseif data.stage == 'success' then
        Log("Successfully found a target!", base)
        return true
    end
    return false
end

return IdentifyTargets
