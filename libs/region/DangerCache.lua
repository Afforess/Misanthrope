require "defines"

--represents the 'danger value' for each pair of x,y coordinates in a region
--danger radiates outword from turrets, decreasing by distance
local DangerCacheClass = {}
local DangerCache = {}
DangerCache.__index = DangerCache

function DangerCache:tostring()
    local cache_str = "[ "
    
    local size = 128
    for dx = 0, size - 1 do
        cache_str = cache_str .. "\n\t["
        for dy = 0, size - 1 do
            if dy > 0 then
                cache_str = cache_str .. ", "
            end
            cache_str = cache_str .. self.danger_cache[dx][dy]
        end
        cache_str = cache_str .. "]"
    end
    cache_str = cache_str .. " ]"

    return "DangerCache {region: ".. self.region:tostring() .. ", cache: ".. cache_str .. "}"
end

function DangerCache:calculate()
    self:reset(false)
    self.calculated_at = game.tick
    
    local area = self.region:regionArea()
    -- examine area +/- 25 blocks around edge of area, turrets may be slightly outside region
    area.lefttop.x = area.lefttop.x - 25
    area.lefttop.y = area.lefttop.y - 25
    area.rightbottom.x = area.rightbottom.x + 25
    area.rightbottom.y = area.rightbottom.y + 25
    
    local turret_names = {"laser-turret", "gun-turret", "gun-turret-2", "biter-emitter"}
    local turret_defense_value = {2000, 100, 600, 300}
    local turret_range = 35
    local surface = game.surfaces.nauvis

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
                    if self.region:isCoordsInside(x_pos, y_pos) then
                        local dist_squared = (x_pos - turret_x) * (x_pos - turret_x) + (y_pos - turret_y) * (y_pos - turret_y)
                        local dist = math.sqrt(dist_squared)
                        local x_idx = bit32.band(x_pos, 0x7F)
                        local y_idx = bit32.band(y_pos, 0x7F)
                        
                        -- eq: y ^ (1/(x ^ (x / 100))). Graph it.
                        local danger = math.pow(defense_value, (1 / (math.pow(dist, (dist / 100)))))
                        self.danger_cache[x_idx][y_idx] = self.danger_cache[x_idx][y_idx] + danger
                    end
                end
            end                
        end
    end
    
    -- update serialized data
    self:save()
end

function DangerCache:save()
    local index = bit32.bor(bit32.lshift(self.region:getX(), 16), bit32.band(self.region:getY(), 0xFFFF))
    global.dangerCache[index] = self:serialize()
end

function DangerCache:getDanger(position)
    local x = math.floor(position.x)
    local y = math.floor(position.y)
    if self.region:isCoordsInside(x, y) then
        local x_idx = bit32.band(x, 0x7F)
        local y_idx = bit32.band(y, 0x7F)
        return self.danger_cache[x_idx][y_idx]
    end
    return -1
end

function DangerCache:reset(save)
    self.danger_cache = {}
    local size = 128

    for x = 0, size - 1 do
        for y = 0, size - 1 do
             if not self.danger_cache[x] then
                 self.danger_cache[x] = {}
             end
             self.danger_cache[x][y] = 0
        end
    end
    if save then
        -- update serialized data
        self:save()
    end
end

function DangerCache:calculatedAt()
    return self.calculated_at
end

function DangerCache:serialize()
    return {calculated_at = self.calculated_at, region = {x = self.region:getX(), y = self.region:getY()}, danger_cache = self.danger_cache}
end

function DangerCacheClass.deserialize(data, RegionClass)
    return setmetatable({calculated_at = data.calculated_at, region = RegionClass.byRegionCoords(data.region), danger_cache = data.danger_cache}, DangerCache)
end

function DangerCacheClass.new(region)
    local self = setmetatable({calculated_at = -1, region = region, danger_cache = {}}, DangerCache)
    self:reset(false)
    return self
end

return DangerCacheClass
