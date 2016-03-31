region_coords = {}
region_coords.__index = region_coords

function region_coords.get_chunk_x(region_data)
    if region_data.x < 0 then
        return bit32.lshift(region_data.x, 2) - MAX_UINT
    end
    return bit32.lshift(region_data.x, 2)
end

function region_coords.get_chunk_y(region_data)
    if region_data.y < 0 then
        return bit32.lshift(region_data.y, 2) - MAX_UINT
    end
    return bit32.lshift(region_data.y, 2)
end

function region_coords.get_lower_pos_x(region_data)
    if region_data.x < 0 then
        return bit32.lshift(region_data.x, 7) - MAX_UINT
    end
    return bit32.lshift(region_data.x, 7)
end

function region_coords.get_lower_pos_y(region_data)
    if region_data.y < 0 then
        return bit32.lshift(region_data.y, 7) - MAX_UINT
    end
    return bit32.lshift(region_data.y, 7)
end

function region_coords.get_upper_pos_x(region_data)
    if (1 + region_data.x) < 0 then
        return bit32.lshift(1 + region_data.x, 7) - MAX_UINT
    end
    return bit32.lshift(1 + region_data.x, 7)
end

function region_coords.get_upper_pos_y(region_data)
    if (1 + region_data.y) < 0 then
        return bit32.lshift(1 + region_data.y, 7) - MAX_UINT
    end
    return bit32.lshift(1 + region_data.y, 7)
end
