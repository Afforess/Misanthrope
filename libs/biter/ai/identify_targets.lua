
local IdentifyTargets = {MAX_DISTANCE = 8}
local Log = function(str, ...) BiterBase.Logger.log(string.format(str, ...)) end

function IdentifyTargets.tick(base)
    local data = base.plan.data
    local distance = data.distance
    local chunk_pos = data.chunk_pos
    if not chunk_pos then
        chunk_pos = Chunk.from_position(base.queen.position)
        distance = 0
    end
    local surface = base.queen.surface
    local chunk_data = Chunk.get_data(surface, chunk_pos)
    if chunk_data and chunk_data.player_scent then
        local highest_scent_chunk = IdentifyTargets.find_largest_scent(surface, chunk_pos, chunk_data)
        if highest_scent_chunk ~= chunk_pos then
            data.chunk_pos = highest_scent_chunk
            data.distance = distance + 1
            if data.distance > IdentifyTargets.MAX_DISTANCE then
                IdentifyTargets.add_target(base, highest_scent_chunk)
                Log("%s | IdentifyTargets: best player scent determined to be at chunk (%d, %d), distance exceeded.", BiterBase.tostring(base), highest_scent_chunk.x, highest_scent_chunk.y)
                return false
            end
        else
            IdentifyTargets.add_target(base, highest_scent_chunk)
            Log("%s | IdentifyTargets: best player scent determined to be at chunk (%d, %d)", BiterBase.tostring(base), highest_scent_chunk.x, highest_scent_chunk.y)
            return false
        end
        Log("%s | IdentifyTargets: best player scent is at chunk (%d, %d)", BiterBase.tostring(base), highest_scent_chunk.x, highest_scent_chunk.y)
        return true
    else
        Log("%s | IdentifyTargets: no player scent. Aborting plan.", BiterBase.tostring(base))
        return false
    end
end

function IdentifyTargets.add_target(base, chunk_pos)
    -- remove any prev existing scents first
    base.targets = table.filter(base.targets, function(target) return target.type ~= 'scent' end)
    table.insert(base.targets, {type = 'scent', chunk_pos = chunk_pos})
end

function IdentifyTargets.find_largest_scent(surface, chunk_pos, chunk_data)
    local highest_scent_chunk = chunk_pos
    local highest_scent = chunk_data.player_scent
    for _, offset in pairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
        local iter_chunk = Position.add(chunk_pos, offset)
        local iter_chunk_data = Chunk.get_data(surface, iter_chunk)
        if iter_chunk_data and iter_chunk_data.player_scent and iter_chunk_data.player_scent > highest_scent then
            highest_scent = iter_chunk_data.player_scent
            highest_scent_chunk = iter_chunk
        end
    end
    return highest_scent_chunk
end

return IdentifyTargets
