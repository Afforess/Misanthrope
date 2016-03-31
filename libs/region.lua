require "libs/region/danger_cache"
require "libs/region/player_target_cache"
require "libs/region/region_coords"

--region is a 4x4 area of chunks

region = {}
region.__index = region

region.REGION_SIZE = 4
region.CHUNK_SIZE = 32
MAX_UINT = 4294967296

function region.get_surface(region_data)
    return game.surfaces[region_data.surface_name]
end

function region.is_coords_inside(region_data, x, y)
    local area = region_data.area
    local left_top = area.left_top
    local right_bottom = area.right_bottom
    return x >= left_top.x and x <= right_bottom.x and y >= left_top.y and y <= right_bottom.y
end

function region.is_position_inside(region_data, pos)
    return region.is_coords_inside(region_data, pos.x, pos.y)
end

function region.tostring(region_data)
    return "Region {x: " .. region_data.x .. ", y: " .. region_data.y .. "}"
end

function region.is_fully_charted(region_data)
    local chunk_x = region_data.chunk_x
    local chunk_y = region_data.chunk_y
    local player_force = game.forces.player
    local surface = region.get_surface(region_data)

    for dx = 0, region.REGION_SIZE do
        for dy = 0, region.REGION_SIZE do
            if not player_force.is_chunk_charted(surface, {chunk_x + dx, chunk_y + dy}) then
                return false
            end
        end
    end
    return true
end

function region.is_partially_charted(region_data)
    local chunk_x = region_data.chunk_x
    local chunk_y = region_data.chunk_y
    local player_force = game.forces.player
    local surface = region.get_surface(region_data)

    for dx = 0, region.REGION_SIZE do
        for dy = 0, region.REGION_SIZE do
            if player_force.is_chunk_charted(surface, {chunk_x + dx, chunk_y + dy}) then
                return true
            end
        end
    end
    return false
end

function region.find_entities(region_data, names, extra_radius)
    local list = {}
    local surface = region.get_surface(region_data)
    local area = region.region_area(region_data, extra_radius)
    for i = 1, #names do
        local temp = surface.find_entities_filtered({area = area, name = names[i]})
        for i = 1, #temp do
    		table.insert(list, temp[i])
    	end
    end
    return list
end

function region.update_biter_base_locations(region_data)
    local spawners = region.find_entities(region_data, {"biter-spawner", "spitter-spawner"}, 0)
    region_data.enemy_bases = {}
    -- mark all spawners as their own bases, then consolidate
    for i = 1, #spawners do
        local spawner = spawners[i]
        local position = { x = math.floor(spawner.position.x), y = math.floor(spawner.position.y) }
        local base = {position = position, spawner_positions = {position}, count = 1}
        table.insert(region_data.enemy_bases, base)
    end
    for i = #region_data.enemy_bases, 1, -1 do
        local base = region_data.enemy_bases[i]
        if base.count == 1 then
            local merged = false

            for j = #region_data.enemy_bases, 1, -1 do
                if i ~= j then
                    local other_base = region_data.enemy_bases[j]
                    for _, position in pairs(other_base.spawner_positions) do
                        local dist_squared = (base.position.x - position.x) * (base.position.x - position.x) + (base.position.y - position.y) * (base.position.y - position.y)
                        -- merge if <= 16 tiles away from any of their spawners
                        if dist_squared <= 256 then
                            table.insert(other_base.spawner_positions, base.position)
                            other_base.count = other_base.count + 1
                            merged = true
                            break
                        end
                    end
                    
                    if merged then
                        break
                    end
                end
            end
            
            if merged then
                table.remove(region_data.enemy_bases, i)
            end
        end
    end

    -- recalculate base position based on center of spawners
    for i = #region_data.enemy_bases, 1, -1 do
        local base = region_data.enemy_bases[i]
        local total_x = 0
        local total_y = 0
        for _, position in pairs(base.spawner_positions) do
            total_x = total_x + position.x
            total_y = total_y + position.y
        end
        base.position = {x = math.floor(total_x / #base.spawner_positions), y = math.floor(total_y / #base.spawner_positions)}
    end
    Logger.log("Updated " .. region.tostring(region_data) .. " biter base locations, found: " .. serpent.line(region_data.enemy_bases))
    return #region_data.enemy_bases > 0
end

function region.region_area(region_data, extra_radius)
    if extra_radius == 0 then
        return region_data.area
    end
	return {left_top = {x = region_data.area.left_top.x - extra_radius, y = region_data.area.left_top.y - extra_radius},
            right_bottom = {x = region_data.area.right_bottom.x + extra_radius, y = region_data.area.right_bottom.y + extra_radius}}
end

function region.offset(region_data, dx, dy)
    return region.lookup_region(region_data.surface_name, region_data.x + dx, region_data.y + dy)
end

function region.get_player_target_cache(region_data)
    local cache = region_data.player_target_cache
    if cache == nil then
        cache = player_target_cache.new(region_data)
        region_data.player_target_cache = cache
    end
    return cache
end

function region.update_player_target_cache(region_data)
    local cache = region.get_player_target_cache(region_data)
    if cache.calculated_at == -1 or (game.tick - cache.calculated_at) > (60 * 60 * 60 * 6) then
        Logger.log(region.tostring(region_data) .. " - Player Target Cache recalculating...")
        player_target_cache.calculate(cache)
        return true
    end
    return false
end

function region.get_player_target_value_at(region_data, position)
    local x = math.floor(position.x)
    local y = math.floor(position.y)
    if region.is_coords_inside(region_data, x, y) then
        region.update_player_target_cache(region_data)

        local cache = region.get_player_target_cache(region_data)
        return player_target_cache.get_value(cache, x, y)
    end

    local other_region = region.lookup_region_from_position(region.get_surface(region_data), position)
    return region.get_player_target_value_at(other_region, position)
end

function region.get_danger_cache(region_data)
    local cache = region_data.danger_cache
    if cache == nil then
        cache = danger_cache.new(region_data)
        region_data.danger_cache = cache
    end
    return cache
end

function region.update_danger_cache(region_data, phase)
    local cache = region.get_danger_cache(region_data)
    if cache.calculated_at == -1 or (game.tick - cache.calculated_at) > (60 * 60 * 60 * 6) then
        Logger.log(region.tostring(region_data) .. " - Danger cache recalculating...")
        danger_cache.calculate(cache, phase)
        return true
    end
    return false
end

function region.get_danger_at(region_data, position)
    local x = math.floor(position.x)
    local y = math.floor(position.y)
    if region.is_coords_inside(region_data, x, y) then
        local cache = region.get_danger_cache(region_data)
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

    local other_region = region.lookup_region_from_position(region.get_surface(region_data), position)
    return region.get_danger_at(other_region, position)
end

-- locations biters have been previously assigned to attack
function region.get_attacked_positions(region_data)
    local index = bit32.bor(bit32.lshift(region_data.x, 16), bit32.band(region_data.y, 0xFFFF))
    local attacked_positions = region_data.attacked_positions
    if attacked_positions == nil then
        attacked_positions = {}
        region_data.attacked_positions = attacked_positions
    end
    return attacked_positions
end

function region.mark_attack_position(region_data, pos)
    local x = math.floor(pos.x)
    local y = math.floor(pos.y)
    local found = false
    local attacked_positions = region.get_attacked_positions(region_data)
    for i = #attacked_positions, 1, -1 do
        local prev_attack = attacked_positions[i]
        if prev_attack.tick + (60 * 60 * 60) < game.tick then
            -- forget attacks longer than 1 hr ago
            table.remove(attacked_positions, i)
        elseif prev_attack.x == x and prev_attack.y == y then
            prev_attack.count = prev_attack.count + 1
            prev_attack.tick = game.tick
            found = true
            break
        end
    end
    if not found then
        table.insert(attacked_positions, { x = x, y = y, count = 1, tick = game.tick })
    end
end

function region.count_attacks_on_position(region_data, pos)
    local x = math.floor(pos.x)
    local y = math.floor(pos.y)
    local attacked_positions = region.get_attacked_positions(region_data)
    for i = 1, #attacked_positions do
        if attacked_positions[i].x == x and attacked_positions[i].y == y then
            return attacked_positions[i].count
        end
    end
    return 0
end

function region.any_potential_targets(region_data, chunk_range)
    local surface = game.surfaces[region_data.surface_name]

    for dx = -(chunk_range), chunk_range do
        for dy = -(chunk_range), chunk_range do
            local tile_x = dx * 32 + region_data.area.left_top.x
            local tile_y = dx * 32 + region_data.area.left_top.y

            local value = region.get_player_target_value_at(region_data, {x = tile_x, y = tile_y})
            if value > 0 then
                return true
            end
        end
    end
    
    return best_position
end

function region.region_key(region_data)
    return string.format("%s@{%s,%s}", region_data.surface_name, region_data.x, region_data.y)
end

function region.lookup_region_key(surface_name, region_x, region_y)
    region.lookup_region(surface_name, region_x, region_y)
    return string.format("%s@{%s,%s}", surface_name, region_x, region_y)
end

function region.lookup_region_from_position(surface, pos)
    local region_x = bit32.arshift(math.floor(pos.x), 7)
    local region_y = bit32.arshift(math.floor(pos.y), 7)
    -- left arithmatic shift returns unsigned int, must add sign back for negative values
    if (pos.x < 0) then
        region_x = region_x - MAX_UINT
    end
    if (pos.y < 0) then
        region_y = region_y - MAX_UINT
    end

    return region.lookup_region(surface.name, region_x, region_y)
end

function region.lookup_region(surface_name, region_x, region_y)
    local region_key = string.format("%s@{%s,%s}", surface_name, region_x, region_y)
    if global.regions[region_key] == nil then
        local region_data = {x = region_x, y = region_y, surface_name = surface_name}
        region.migrate_regions(region_data)
        global.regions[region_key] = region_data
    end

    return global.regions[region_key]
end

function region.migrate_regions(region_data)
    if not region_data.version then
        region_data.version = 1
    end
    if region_data.version < 2 then
        region_data.version = 2
        region_data.chunk_x = region_coords.get_chunk_x(region_data)
        region_data.chunk_y = region_coords.get_chunk_y(region_data)

        region_data.area = {left_top = {}, right_bottom = {}}
        region_data.area.left_top.x = region_coords.get_lower_pos_x(region_data)
        region_data.area.left_top.y = region_coords.get_lower_pos_y(region_data)
        region_data.area.right_bottom.x = region_coords.get_upper_pos_x(region_data)
        region_data.area.right_bottom.y = region_coords.get_upper_pos_y(region_data)
    end
end
