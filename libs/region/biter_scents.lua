biter_scents = {}
biter_scents.__index = biter_scents

function biter_scents.get_region(cache)
    return global.regions[cache.region_key]
end

function biter_scents.tostring(cache)
    local cache_str = "[ "

    local size = 128
    for dx = 0, size - 1 do
        cache_str = cache_str .. "\n\t["
        for dy = 0, size - 1 do
            if dy > 0 then
                cache_str = cache_str .. ", "
            end
            cache_str = cache_str .. cache.values[dx][dy]
        end
        cache_str = cache_str .. "]"
    end
    cache_str = cache_str .. " ]"

    return "BiterScents {region: ".. region.tostring(biter_scents.get_region(cache)) .. ", cache: ".. cache_str .. "}"end

function biter_scents.entity_died(cache, entity)
    if cache.all_zeros then
        cache.all_zeros = nil
        cache.values = {}
    end
    local max_health = entity.prototype.max_health
    local position = entity.position
    local entity_x = math.floor(entity.position.x)
    local entity_y = math.floor(entity.position.y)
    
    local region_data = biter_scents.get_region(cache)
    local surface = region.get_surface(region_data)
    local radius = math.floor(math.min(40, math.max(5, math.sqrt(max_health))))
    for dx = -(radius), radius do
        for dy = (-radius), radius do
            local x_pos = entity_x + dx
            local y_pos = entity_y + dy
            
            local axbx = (x_pos - entity_x)
            local ayby = (y_pos - entity_y)
            local dist_squared = axbx * axbx + ayby * ayby
            
            local delta = math.floor(max_health / math.pow(dist_squared, 0.25))
            if delta > 1 then
                if region.is_coords_inside(region_data, x_pos, y_pos) then
                    biter_scents.change_value(cache, x_pos, y_pos, delta)
                else
                    local other_region = region.lookup_region_from_position(surface, {x = x_pos, y = y_pos})
                    local other_cache = region.get_biter_scent_cache(other_region)
                    biter_scents.change_value(other_cache, x_pos, y_pos, delta)
                end
            end
        end
    end
end

function biter_scents.change_value(cache, x, y, delta)
    if cache.all_zeros then
        cache.all_zeros = nil
        cache.values = {}
    end

    local x_idx = bit32.band(x, 0x7F)
    local y_idx = bit32.band(y, 0x7F)

    local prev_value = 0
    if not cache.values[x_idx] then
        cache.values[x_idx] = {}
    elseif cache.values[x_idx][y_idx] then
        prev_value = cache.values[x_idx][y_idx]
    end
    cache.values[x_idx][y_idx] = prev_value + delta
end

function biter_scents.tick(cache)
    if not cache.all_zeros then
        local size = 128
        local any_values = false
        for dx = 0, size - 1 do
            if cache.values[dx] then
                for dy = 0, size - 1 do
                    local value = 0
                    if cache.values[dx][dy] then
                        if cache.values[dx][dy] > 1 then
                            cache.values[dx][dy] = math.floor(cache.values[dx][dy] * 0.95)
                            any_values = true
                        else
                            cache.values[dx][dy] = 0
                        end
                    end
                end
            end
        end

        -- compress data structure if possible
        if not any_values then
            cache.values = nil
            cache.all_zeros = true
        else
            for x = 0, size - 1 do
                local any_values_in_row = false
                if cache.values[x] then
                    for y = 0, size - 1 do
                         if cache.values[x][y] and cache.values[x][y] > 0 then
                             any_values_in_row = true
                             break
                         end
                    end
                    if not any_values_in_row then
                        cache.values[x] = nil
                    end
                end
            end
        end
    end
end

function biter_scents.get_value(cache, x, y)
    if cache and cache.values then
        local x_idx = bit32.band(x, 0x7F)
        local y_idx = bit32.band(y, 0x7F)
        if cache.values[x_idx] and cache.values[x_idx][y_idx] then
            return cache.values[x_idx][y_idx]
        end
    end
    return 0
end

function biter_scents.get_avg_value_for_chunk(cache, chunk_x, chunk_y)
    local avg = 0
    local count = 0
    local x = chunk_x * 32
    local y = chunk_y * 32
    for dx = 0, 32 do
        for dy = 0, 32 do
            local x_idx = bit32.band(x + dx, 0x7F)
            local y_idx = bit32.band(y + dy, 0x7F)
            if cache.values[x_idx] and cache.values[x_idx][y_idx] then
                avg = avg + cache.values[x_idx][y_idx]
            end
            count = count + 1
        end
    end
    return math.floor(avg / count)
end

function biter_scents.new(region_data)
    local naunce = global.naunce
    global.naunce = global.naunce + 1
    local scents = global.biter_scents[global.naunce % 3600]
    if not scents then
        scents = {}
        global.biter_scents[global.naunce % 3600] = scents
    end
    local obj = {all_zeros = true, region_key = region.region_key(region_data), naunce = naunce}
    table.insert(scents, obj)

    return obj
end
