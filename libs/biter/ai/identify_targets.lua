require 'libs/pathfinding_engine'

local IdentifyTargets = {MAX_DISTANCE = 8}
local Log = function(str, base, ...) BiterBase.Logger.log(string.format("[IdentifyTargets] - (" .. base.name .. "): " .. str, ...)) end

function IdentifyTargets.tick(base, data)
    local chunk_pos = data.chunk_pos
    local start_pos = nil
    if not chunk_pos then
        chunk_pos = Chunk.from_position(base.queen.position)
        start_pos = base.queen.position
    end
    if not start_pos then start_pos = Area.center(Chunk.to_area(chunk_pos)) end
    if not data.paths then data.paths = {} end
    if not data.potential_candidates then data.potential_candidates = {} end
    if not data.distance then data.distance = 0 end

    local surface = base.queen.surface

    -- when data.pending_candidate exists, we have made a request to find a path to a candidate chunk and are
    -- waiting on the pathfinding engine completing our request sometime in the future
    if data.pending_candidate then
        local candidate_chunk, path_id = unpack(data.pending_candidate)
        -- poll the pathfinding engine until the pathfinding is completed
        if not PathfindingEngine.is_path_complete(path_id) then
            return true
        end

        local result = PathfindingEngine.retreive_path(path_id)
        if result.path then
            Log("found path to candidate chunk (%d, %d): %s", base, candidate_chunk.x, candidate_chunk.y, serpent.line(result.path, {comment = false}))
            table.insert(data.candidates, {candidate_chunk, result.path})
        else
            Log("no path found to candidate chunk (%d, %d)", base, candidate_chunk.x, candidate_chunk.y)
        end
        data.pending_candidate = nil

        -- all adjacent chunks have paths generated, choose the chunk with the best path
        if #data.potential_candidates == 0 then
            return IdentifyTargets.choose_candidate(base, data, chunk_pos)
        end
    end

    -- examine adjacent candidate chunks for valid paths
    Log("%d candidate chunks", base, #data.potential_candidates)
    if #data.potential_candidates > 0 then
        local candidate_chunk = table.remove(data.potential_candidates, 1)
        Log("examining candidate chunk (%d, %d)", base, candidate_chunk.x, candidate_chunk.y)
        IdentifyTargets.examine_candidate(base, data, surface, start_pos, candidate_chunk)
        return true
    end

    if data.distance > IdentifyTargets.MAX_DISTANCE then
        base.target = {type = 'scent', chunk_pos = chunk_pos, paths = data.paths}
        Log("best player scent determined to be at chunk (%d, %d) - distance exceeded", base, chunk_pos.x, chunk_pos.y)
        return false
    end

    local chunk_data = Chunk.get_data(surface, chunk_pos)

    if not chunk_data then
        Log("no player scent. Aborting plan.", base)
        return false
    end
    if not chunk_data.player_scent or chunk_data.player_scent < 100 then
        Log("no player scent. Aborting plan.", base)
        return false
    end

    local candidates = IdentifyTargets.find_candidates(base, surface, chunk_pos, math.floor(chunk_data.player_scent * 0.75))
    if #candidates == 0 then
        if data.paths then
            base.target = {type = 'scent', chunk_pos = chunk_pos, paths = data.paths}
            Log("best player scent determined to be at chunk (%d, %d)", base, chunk_pos.x, chunk_pos.y)
            Log("target data: %s", base, serpent.line(base.target, {comment = false}))
        else
            base.target = nil
            Log("no path found to player scent", base)
        end
        return false
    end

    Log("potential candidates: %d, %s", base, #candidates, serpent.line(candidates, {comment = false}))
    data.potential_candidates = candidates
    data.candidates = {}
    return true
end

function IdentifyTargets.choose_candidate(base, data, chunk_pos)
    local shortest_path = nil
    local best_candidate = -1
    Log("choosing candidates: %s", base, serpent.line(data.candidates, {comment = false}))

    for i = 1, #data.candidates do
        local candidate_chunk, result = unpack(data.candidates[i])
        if shortest_path == nil or #result < shortest_path then
            best_candidate = i
            shortest_path = #result
        end
    end

    -- found an adjacent chunk with a path we can travel to
    if shortest_path then
        local candidate_chunk, result = unpack(data.candidates[best_candidate])
        data.chunk_pos = candidate_chunk
        data.distance = data.distance + 1
        table.insert(data.paths, result)
        data.potential_candidates = {}
        data.candidates = {}
        Log("choose candidate chunk, continuing (%d, %d): %s", base, chunk_pos.x, chunk_pos.y, serpent.line(data.paths, {comment = false}))
        return true
    else
        base.target = {type = 'scent', chunk_pos = chunk_pos, paths = data.paths}
        Log("best player scent determined to be at chunk (%d, %d)", base, chunk_pos.x, chunk_pos.y)
        return false
    end
end

function IdentifyTargets.examine_candidate(base, data, surface, start_pos, candidate_chunk)
    local end_pos = Area.center(Chunk.to_area(candidate_chunk))
    Log("searching for path from %s to %s", base, serpent.line(start_pos, {comment = false}), serpent.line(end_pos, {comment = false}))
    local path_id = PathfindingEngine.request_path(surface, start_pos, end_pos, 1000)
    data.pending_candidate = {candidate_chunk, path_id}
end

--- Returns a list of adjacent chunks that have a higher player scent than the given chunk
function IdentifyTargets.find_candidates(base, surface, chunk_pos, min_scent)
    local candidates = {}
    Log("searching for candidates adjacent to (%d, %d), min_scent: %d", base, chunk_pos.x, chunk_pos.y, min_scent)
    for x, y in Area.iterate(Position.expand_to_area(chunk_pos, 1)) do
        if x ~= chunk_pos.x and y ~= chunk_pos.y then
            local chunk_data = Chunk.get_data(surface, {x = x, y = y})
            if chunk_data and chunk_data.player_scent and chunk_data.player_scent > min_scent then
                table.insert(candidates, {x = x, y = y})
            end
        end
    end
    return candidates
end

return IdentifyTargets
