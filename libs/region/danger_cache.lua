--represents the 'danger value' for each pair of x,y coordinates in a region
--danger radiates outword from turrets, decreasing by distance
danger_cache = {}
danger_cache.__index = danger_cache

function danger_cache.get_region(cache)
    return global.regions[cache.region_key]
end

function danger_cache.tostring(cache)
    local cache_str = "[ "
    
    local size = 128
    for dx = 0, size - 1 do
        cache_str = cache_str .. "\n\t["
        for dy = 0, size - 1 do
            if dy > 0 then
                cache_str = cache_str .. ", "
            end
            cache_str = cache_str .. cache.danger_cache[dx][dy]
        end
        cache_str = cache_str .. "]"
    end
    cache_str = cache_str .. " ]"

    return "DangerCache {region: ".. region.tostring(danger_cache.get_region(cache)) .. ", cache: ".. cache_str .. "}"
end

function danger_cache.calculate(cache)
    cache.all_zeros = nil
    cache.danger_cache = {}
    local size = 128
    for x = 0, size - 1 do
        for y = 0, size - 1 do
             if not cache.danger_cache[x] then
                 cache.danger_cache[x] = {}
             end
             cache.danger_cache[x][y] = 0
        end
    end
    cache.calculated_at = game.tick
    
    local region_data = danger_cache.get_region(cache)
    local area = region.region_area(region_data, 0)
    -- examine area +/- 25 blocks around edge of area, turrets may be slightly outside region
    area.left_top.x = area.left_top.x - 25
    area.left_top.y = area.left_top.y - 25
    area.right_bottom.x = area.right_bottom.x + 25
    area.right_bottom.y = area.right_bottom.y + 25
    
    local turret_names = {"laser-turret", "gun-turret", "gun-turret-2", "biter-emitter"}
    local turret_defense_value = {2000, 100, 600, 300}
    local turret_range = 35
    local surface = region.get_surface(region_data)

    local any_values = false
    for i = 1, #turret_names do
        local turret_entities = surface.find_entities_filtered({area = area, name = turret_names[i]})
        for j = 1, #turret_entities do
            local turret = turret_entities[j]
            local turret_x = turret.position.x
            local turret_y = turret.position.y
            local defense_value = turret_defense_value[i] * 100
            for dx = -turret_range, turret_range do
                for dy = -turret_range, turret_range do
                    local x_pos = math.floor(turret_x + dx)
                    local y_pos = math.floor(turret_y + dy)
                    if region.is_coords_inside(region_data, x_pos, y_pos) then
                        local dist_squared = (x_pos - turret_x) * (x_pos - turret_x) + (y_pos - turret_y) * (y_pos - turret_y)
                        local dist = math.sqrt(dist_squared)
                        local x_idx = bit32.band(x_pos, 0x7F)
                        local y_idx = bit32.band(y_pos, 0x7F)
                        
                        -- eq: y ^ (1/(x ^ (x / 100))). Graph it.
                        local danger = math.pow(defense_value, (1 / (math.pow(dist, (dist / 100)))))
                        cache.danger_cache[x_idx][y_idx] = cache.danger_cache[x_idx][y_idx] + danger
                        
                        any_values = true
                    end
                end
            end                
        end
    end
    
    if not any_values then
        cache.danger_cache = nil
        cache.all_zeros = true
    end
end

function danger_cache.get_danger(cache, position)
    local x = math.floor(position.x)
    local y = math.floor(position.y)
    local region_data = danger_cache.get_region(cache)
    if region.is_coords_inside(region_data, x, y) then
        if cache.all_zeros then
            return 0
        end
        local x_idx = bit32.band(x, 0x7F)
        local y_idx = bit32.band(y, 0x7F)
        return cache.danger_cache[x_idx][y_idx]
    end
    return -1
end

function danger_cache.reset(cache)
    cache.danger_cache = {all_zeros = true, region_key = cache.region_key, calculated_at = -1}
end

function danger_cache.new(region_data)
    return {all_zeros = true, region_key = region.region_key(region_data), calculated_at = -1}
end
