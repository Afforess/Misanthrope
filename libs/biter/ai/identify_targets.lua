require 'libs/pathfinding_engine'

local IdentifyTargets = {MAX_DISTANCE = 8}
local Log = function(str, ...) BiterBase.Logger.log(string.format(str, ...)) end

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

    -- pending the pathfinding engine completing our request sometime in the future
    if data.pending_candidate then
        local candidate_chunk, path_id = unpack(data.pending_candidate)
        if PathfindingEngine.is_path_complete(path_id) then
            local result = PathfindingEngine.retreive_path(path_id)
            if result.path then
                Log("%s | IdentifyTargets: found path to candidate chunk (%d, %d): %s", BiterBase.tostring(base), candidate_chunk.x, candidate_chunk.y, serpent.line(result.path, {comment = false}))
                table.insert(data.candidates, {candidate_chunk, result.path})
            else
                Log("%s | IdentifyTargets: no path found to candidate chunk (%d, %d)", BiterBase.tostring(base), candidate_chunk.x, candidate_chunk.y)
            end
            data.pending_candidate = nil

            -- all chunks have paths generated (or failed to generate a path)
            if #data.potential_candidates == 0 then
                return IdentifyTargets.choose_candidate(base, data, chunk_pos)
            end
        end
        return true
    end

    -- examine adjacent candidate chunks for valid paths
    Log("%s | IdentifyTargets: %d candidate chunks", BiterBase.tostring(base), #data.potential_candidates)
    if #data.potential_candidates > 0 then
        local candidate_chunk = table.remove(data.potential_candidates, 1)
        Log("%s | IdentifyTargets: examining candidate chunk (%d, %d)", BiterBase.tostring(base), candidate_chunk.x, candidate_chunk.y)
        IdentifyTargets.examine_candidate(base, data, surface, start_pos, candidate_chunk)
        return true
    end

    if data.distance > IdentifyTargets.MAX_DISTANCE then
        base.target = {type = 'scent', chunk_pos = chunk_pos, paths = data.paths}
        Log("%s | IdentifyTargets: best player scent determined to be at chunk (%d, %d) - distance exceeded", BiterBase.tostring(base), chunk_pos.x, chunk_pos.y)
        return false
    end

    local chunk_data = Chunk.get_data(surface, chunk_pos)

    if not chunk_data then
        Log("%s | IdentifyTargets: no player scent. Aborting plan.", BiterBase.tostring(base))
        return false
    end
    if not chunk_data.player_scent or chunk_data.player_scent < 100 then
        Log("%s | IdentifyTargets: no player scent. Aborting plan.", BiterBase.tostring(base))
        return false
    end

    local candidates = IdentifyTargets.find_candidates(base, surface, chunk_pos, math.floor(chunk_data.player_scent * 0.75))
    if #candidates == 0 then
        if data.paths then
            base.target = {type = 'scent', chunk_pos = chunk_pos, paths = data.paths}
            Log("%s | IdentifyTargets: best player scent determined to be at chunk (%d, %d)", BiterBase.tostring(base), chunk_pos.x, chunk_pos.y)
        else
            base.target = nil
            Log("%s | IdentifyTargets: no path found to player scent", BiterBase.tostring(base))
        end
        return false
    end

    Log("%s | IdentifyTargets: potential candidates: %d, %s", BiterBase.tostring(base), #candidates, serpent.line(candidates, {comment = false}))
    data.potential_candidates = candidates
    data.candidates = {}
    return true
end

function IdentifyTargets.choose_candidate(base, data, chunk_pos)
    local shortest_path = nil
    local best_candidate = -1
    Log("%s | IdentifyTargets: choosing candidates: %s", BiterBase.tostring(base), serpent.line(data.candidates, {comment = false}))

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
        Log("%s | IdentifyTargets: choose candidate chunk, continuing (%d, %d): %s", BiterBase.tostring(base), chunk_pos.x, chunk_pos.y, serpent.line(data.paths, {comment = false}))
        return true
    else
        base.target = {type = 'scent', chunk_pos = chunk_pos, paths = data.paths}
        Log("%s | IdentifyTargets: best player scent determined to be at chunk (%d, %d)", BiterBase.tostring(base), chunk_pos.x, chunk_pos.y)
        return false
    end
end

function IdentifyTargets.examine_candidate(base, data, surface, start_pos, candidate_chunk)
    local end_pos = Area.center(Chunk.to_area(candidate_chunk))
    Log("%s | IdentifyTargets: searching for path from %s to %s", BiterBase.tostring(base), serpent.line(start_pos, {comment = false}), serpent.line(end_pos, {comment = false}))
    local path_id = PathfindingEngine.request_path(surface, start_pos, end_pos, 1000)
    data.pending_candidate  = {candidate_chunk, path_id}
end

--- Returns a list of adjacent chunks that have a higher player scent than the given chunk
function IdentifyTargets.find_candidates(base, surface, chunk_pos, min_scent)
    local candidates = {}
    Log("%s | IdentifyTargets: searching for candidates adjacent to (%d, %d), min_scent: %d", BiterBase.tostring(base), chunk_pos.x, chunk_pos.y, min_scent)
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
