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

function danger_cache.num_turrets()
    return #danger_cache.all_turrets().turret_names
end

function danger_cache.all_turrets()
    local turret_names = { "biter-emitter" }
    local turret_defense_value = { 500 }
    local max_range = 25
    for entity_name, entity_prototype in pairs(game.entity_prototypes) do
        if entity_prototype.type == "ammo-turret" or entity_prototype.type == "electric-turret" then
            table.insert(turret_names, entity_name)
            table.insert(turret_defense_value, entity_prototype.turret_range * 40)
            max_range = math.max(max_range, entity_prototype.turret_range)
        end
    end
    return { turret_names = turret_names, turret_defense_value = turret_defense_value, max_range = max_range }
end

function danger_cache.calculate(cache, index)
    if index == 1 then
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
    end

    local region_data = danger_cache.get_region(cache)
    -- examine area +/- 25 blocks around edge of area, turrets may be slightly outside region
    local region_area = region.region_area(region_data, 0)
    local left_top_x = region_area.left_top.x
    local left_top_y = region_area.left_top.y
    local right_bottom_x = region_area.right_bottom.x
    local right_bottom_y = region_area.right_bottom.y

    -- find all the turrets in the game... biter-emitter is a special case as it's not a turret
    local turret_data = danger_cache.all_turrets()
    local turret_names = turret_data.turret_names
    local turret_defense_value = turret_data.turret_defense_value
    local max_range = turret_data.max_range
    Logger.log("Turret data: " .. serpent.line(turret_data) .. ", Index: " .. serpent.line(index))

    -- past 40, too difficult to calculate
    max_range = math.min(40, max_range)

    local area = region.region_area(region_data, max_range)
    local surface = region.get_surface(region_data)

    local any_values = false
    local turret_entities = surface.find_entities_filtered({area = area, name = turret_names[index]})
    for j = 1, #turret_entities do
        local turret = turret_entities[j]
        local turret_x = math.floor(turret.position.x)
        local turret_y = math.floor(turret.position.y)
        local defense_value = turret_defense_value[index] * 100
        for dx = -max_range, max_range do
            for dy = -max_range, max_range do
                local x_pos = turret_x + dx
                local y_pos = turret_y + dy
                if x_pos >= left_top_x and x_pos <= right_bottom_x and y_pos >= left_top_y and y_pos <= right_bottom_y then
                    local axbx = (x_pos - turret_x)
                    local ayby = (y_pos - turret_y)
                    local dist_squared = axbx * axbx + ayby * ayby

                    local x_idx = bit32.band(x_pos, 0x7F)
                    local y_idx = bit32.band(y_pos, 0x7F)

                    local danger = defense_value * (max_range / (max_range + (dist_squared / 5)))
                    cache.danger_cache[x_idx][y_idx] = cache.danger_cache[x_idx][y_idx] + danger
                    any_values = true
                end
            end
        end
    end

    if index == #turret_names then
        cache.calculated_at = game.tick

        if not any_values then
            cache.danger_cache = nil
            cache.all_zeros = true
        else
            for x = 0, size - 1 do
                local any_values_in_row = false
                for y = 0, size - 1 do
                     cache.danger_cache[x][y] = 0
                     if cache.danger_cache[x][y] > 0 then
                         any_values_in_row = true
                         -- convert to integers and set the min value to 1
                         cache.danger_cache[x][y] = math.floor(math.max(1, cache.danger_cache[x][y]))
                     end
                end
                if not any_values_in_row then
                    cache.danger_cache[x] = nil
                end
            end
        end
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
        if cache.danger_cache[x_idx] then
            return cache.danger_cache[x_idx][y_idx]
        end
        return 0
    end
    return -1
end

function danger_cache.new(region_data)
    return {all_zeros = true, region_key = region.region_key(region_data), calculated_at = -1}
end
