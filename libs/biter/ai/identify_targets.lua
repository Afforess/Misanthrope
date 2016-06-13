require 'libs/pathfinding_engine'

local IdentifyTargets = {stages = {}}
local Log = function(str, base, ...) BiterBase.Logger.log(string.format("[IdentifyTargets] - (" .. base.name .. "): " .. str, ...)) end

IdentifyTargets.stages.setup = function(base, data)
    local chunk_pos = Chunk.from_position(base.queen.position)
    local search_area = Position.expand_to_area(chunk_pos, 12)
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
        value = chunk_data.player_value / (1 + Position.manhattan_distance(chunk_pos, data.start_chunk))
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
        local a_value = a.value
        local b_value = b.value
        return b_value < a_value
    end)

    Log("All candidates: %s", base, serpent.block(data.candidates))

    return 'pathfind'
end

IdentifyTargets.stages.pathfind = function(base, data)
    if data.path_finding.idx > #data.candidates then
        return 'decide'
    end

    local candidate = data.candidates[data.path_finding.idx]
    local end_pos = Area.center(Chunk.to_area(candidate.chunk_pos))
    data.path_finding.path_id = PathfindingEngine.request_path(base.queen.surface, base.queen.position, end_pos, 50000)
    return 'wait_for_path'
end

IdentifyTargets.stages.wait_for_path = function(base, data)
    local path_id = data.path_finding.path_id
    if not PathfindingEngine.is_path_complete(path_id) then
        return 'wait_for_path'
    end

    local result = PathfindingEngine.retreive_path(path_id)
    if result.path then
        local candidate = data.candidates[data.path_finding.idx]
        candidate.path = result.path
        Log("Found path for candidate chunk (%s)", base, serpent.line(candidate.chunk_pos))
        return 'decide'
    end

    data.path_finding.idx = data.path_finding.idx + 1
    return 'pathfind'
end

IdentifyTargets.stages.decide = function(base, data)
    local path_candidates = table.filter(data.candidates, function(candidate)
        return candidate.path ~= nil
    end)

    table.sort(path_candidates, function(a, b)
        local a_value = a.data.player_value
        local b_value = b.data.player_value
        return b_value < a_value
    end)

    if #path_candidates == 0 then
        return 'fail'
    end

    local idx = math.random(#path_candidates)
    local choosen_candidate = path_candidates[idx]
    Log("Randomly chosen candidate was %s", base, serpent.line(choosen_candidate))
    base.target = { type = 'player_value', chunk_pos = choosen_candidate.chunk_pos, path = choosen_candidate.path }
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
