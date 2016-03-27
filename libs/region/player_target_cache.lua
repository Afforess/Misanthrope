--represents the value of player items to biters for each chunk in a region
player_target_cache = {}
player_target_cache.__index = player_target_cache

function player_target_cache.get_region(cache)
    return global.regions[cache.region_key]
end

function player_target_cache.tostring(cache)
    local cache_str = "[ "
    
    for chunk_x = 0, 4 do
        for chunk_y = 0, 4 do
            local idx = bit32.band(bit32.bor(bit32.lshift(bit32.band(chunk_x, 0x3), 2), bit32.band(chunk_y, 0x3)), 0xF)
            if not cache.all_zeros then
                cache_str = cache_str .. "\n\t{Chunk (" .. chunk_x .. ", " .. chunk_y .. ") value: " .. cache.values[idx] .. "}"
            else
                cache_str = cache_str .. "\n\t{Chunk (" .. chunk_x .. ", " .. chunk_y .. ") value: 0}"
            end
        end
    end
    cache_str = cache_str .. " ]"

    return "PlayerTargetCache {region: ".. region.tostring(player_target_cache.get_region(cache)) .. ", cache (calculated_at: " .. cache.calculated_at .. "): ".. cache_str .. "}"
end

function player_target_cache.calculate(cache)
    cache.all_zeros = nil
    cache.values = {}
    local size = 16
    for x = 0, size - 1 do
        cache.values[x] = 0
    end
    cache.calculated_at = game.tick
    
    local region_data = player_target_cache.get_region(cache)
    local area = region.region_area(region_data, 0)
    local surface = region.get_surface(region_data)

    local any_values = false
    for entity_name, target_data in pairs(BITER_TARGETS) do
        local entities = surface.find_entities_filtered({area = area, name = entity_name})
        for i = 1, #entities do
            local entity = entities[i]
            if entity.force ~= game.forces.enemy and entity.force ~= game.forces.neutral then
                local entity_x = math.floor(entity.position.x)
                local entity_y = math.floor(entity.position.y)
                local value = target_data.value
                local danger = region.get_danger_at(region_data, entity.position)
                value = math.max(1, math.floor(value / (1 + danger)))
                
                local chunk_x = bit32.arshift(entity_x, 5)
                if entity_x < 0 then
                    chunk_x = chunk_x - MAX_UINT
                end
                local chunk_y = bit32.arshift(entity_y, 5)
                if entity_y < 0 then
                    chunk_y = chunk_y - MAX_UINT
                end
                
                local idx = bit32.band(bit32.bor(bit32.lshift(bit32.band(chunk_x, 0x3), 2), bit32.band(chunk_y, 0x3)), 0xF)
                cache.values[idx] = cache.values[idx] + value
                any_values = true
            end
        end
    end

    if not any_values then
        cache.values = nil
        cache.all_zeros = true
    end
end

function player_target_cache.get_value(cache, x, y)
    if cache.all_zeros then
        return 0
    end
    local chunk_x = bit32.arshift(x, 5)
    if x < 0 then
        chunk_x = chunk_x - MAX_UINT
    end
    local chunk_y = bit32.arshift(y, 5)
    if y < 0 then
        chunk_y = chunk_y - MAX_UINT
    end
    
    local idx = bit32.band(bit32.bor(bit32.lshift(bit32.band(chunk_x, 0x3), 2), bit32.band(chunk_y, 0x3)), 0xF)
    return cache.values[idx]
end

function player_target_cache.new(region_data)
    return {all_zeros = true, region_key = region.region_key(region_data), calculated_at = -1}
end
