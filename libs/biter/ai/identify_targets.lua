require 'libs/pathfinding_engine'

local IdentifyTargets = {stages = {}}
local Log = function(str, ...) BiterBase.LogAI("[IdentifyTargets] " .. str, ...) end

IdentifyTargets.search_radius = 40
IdentifyTargets.search_queue = {}
for dx, dy in Area.spiral_iterate(Position.expand_to_area({0, 0}, IdentifyTargets.search_radius)) do
    table.insert(IdentifyTargets.search_queue, {x = dx, y = dy})
end
IdentifyTargets.search_queue_size = #IdentifyTargets.search_queue

function IdentifyTargets.search_queue_chunk(base, data)
    local idx = data.search_idx
    local center = base.chunk_pos
    local delta_pos = IdentifyTargets.search_queue[idx]
    return { x = center.x + delta_pos.x, y = center.y + delta_pos.y }
end

IdentifyTargets.stages.setup = function(base, data)
    data.search_idx = 1
    data.candidates = {}
    data.path_finding = { idx = 1, path_id = -1}
    data.completed = false
    return 'search'
end

IdentifyTargets.stages.search = function(base, data)
    if data.search_idx > IdentifyTargets.search_queue_size then
        return 'sort'
    end
    local chunk_pos = IdentifyTargets.search_queue_chunk(base, data)

    local chunk_value = World.get_chunk_value(base.surface, chunk_pos)
    if chunk_value > 0 then
        local dist = Position.manhattan_distance(chunk_pos, base.chunk_pos)

        value = (chunk_value * chunk_value) / ((1 + dist) * (1 + dist))
        table.insert(data.candidates, { chunk_pos = chunk_pos, value = math.floor(value)})
    end

    data.search_idx = data.search_idx + 1
    return 'search'
end

IdentifyTargets.stages.sort = function(base, data)
    if #data.candidates == 0 then
        Log("No candidates, unable to identify any targets.", base)
        base.targets = { candidates = {}, tick = game.tick }
        return 'fail'
    end
    table.sort(data.candidates, function(a, b)
        return b.value < a.value
    end)

    Log("All candidates: %s", base, string.block(data.candidates))
    data.candidates = table.filter(data.candidates, function(candidate)
        return candidate.value > 100
    end)
    if #data.candidates == 0 then
        Log("No candidates, unable to identify any valuable targets.", base)
        base.targets = { candidates = {}, tick = game.tick }
        return 'fail'
    end
    Log("Filtered candidates: %s", base, string.block(data.candidates))
    local max_candidates = math.min(20, #data.candidates)
    local base_candidates = {}
    for i = 1, max_candidates do
        base_candidates[i] = data.candidates[i].chunk_pos
    end

    base.targets = { candidates = base_candidates, tick = game.tick }
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
