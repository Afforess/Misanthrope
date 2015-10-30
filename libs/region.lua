require "defines"
local DangerCache = require "libs/region/DangerCache"

--region is a 4x4 area of chunks
local RegionClass = {}
local Region = {}
Region.__index = Region

REGION_SIZE = 4
CHUNK_SIZE = 32
MAX_UINT = 4294967296

function Region:getX()
    return self.x
end

function Region:getY()
    return self.y
end

function Region:getChunkX()
    if self.x < 0 then
        return bit32.lshift(self.x, 2) - MAX_UINT
    end
    return bit32.lshift(self.x, 2)
end

function Region:getChunkY()
    if self.y < 0 then
        return bit32.lshift(self.y, 2) - MAX_UINT
    end
    return bit32.lshift(self.y, 2)
end

function Region:getLowerXPos()
    if self.x < 0 then
        return bit32.lshift(self.x, 7) - MAX_UINT
    end
    return bit32.lshift(self.x, 7)
end

function Region:getLowerYPos()
    if self.y < 0 then
        return bit32.lshift(self.y, 7) - MAX_UINT
    end
    return bit32.lshift(self.y, 7)
end

function Region:getUpperXPos()
    if (1 + self.x) < 0 then
        return bit32.lshift(1 + self.x, 7) - MAX_UINT
    end
    return bit32.lshift(1 + self.x, 7)
end

function Region:getUpperYPos()
    if (1 + self.y) < 0 then
        return bit32.lshift(1 + self.y, 7) - MAX_UINT
    end
    return bit32.lshift(1 + self.y, 7)
end

function Region:isCoordsInside(x, y)
    return x > self:getLowerXPos() and x < self:getUpperXPos() and y > self:getLowerYPos() and y < self:getUpperYPos()
end

function Region:isPositionInside(pos)
    return self:isCoordsInside(pos.x, pos.y)
end

function Region:tostring()
    return "Region {x: ".. self.x .. ", y: ".. self.y .. "}"
end

function Region:isFullyCharted()
    local chunkX = self:getChunkX()
    local chunkY = self:getChunkY()
    local player_force = game.forces.player
    
    for _, surface in pairs(game.surfaces) do
        for dx = 0, REGION_SIZE do
            for dy = 0, REGION_SIZE do
                if not player_force.is_chunk_charted(surface, {chunkX + dx, chunkY + dy}) then
                    return false
                end
            end
        end
    end
    return true
end

function Region:isPartiallyCharted()
    local chunkX = self:getChunkX()
    local chunkY = self:getChunkY()
    local player_force = game.forces.player
    
    for _, surface in pairs(game.surfaces) do
        for dx = 0, REGION_SIZE do
            for dy = 0, REGION_SIZE do
                if player_force.is_chunk_charted(surface, {chunkX + dx, chunkY + dy}) then
                    return true
                end
            end
        end
    end
    return false
end

function Region:findEntities(nameList)
    local entityList = {}
    local surface = game.surfaces.nauvis
    local region_area = self:regionArea()
    for i=1, #nameList do
        local temp = surface.find_entities_filtered({area = region_area, name = nameList[i]})
        entityList = mergeTables(entityList, temp)
    end
    return entityList
end

function Region:regionArea()
	return {lefttop = {x = self:getLowerXPos(), y = self:getLowerYPos()}, rightbottom = {x = self:getUpperXPos(), y = self:getUpperYPos()}}
end

function Region:offset(dx, dy)
    return RegionClass.byRegionCoords({x = self.x + dx, y = self.y + dy})
end

function Region:getDangerCache()
    return self.danger_cache
end

-- create region from factorio position
function RegionClass.new(pos)
    local self = setmetatable({}, Region)
    self.x = bit32.arshift(math.floor(pos.x), 7)
    -- left arithmatic shift returns unsigned int, must add sign back for negative values
    if (pos.x < 0) then
        self.x = self.x - MAX_UINT
    end
    self.y = bit32.arshift(math.floor(pos.y), 7)
    if (pos.y < 0) then
        self.y = self.y - MAX_UINT
    end
    self.danger_cache = DangerCache.new(self)
    
    return self
end

-- create region from region coordinates
function RegionClass.byRegionCoords(regionCoords)
    local self = setmetatable({}, Region)
    self.x = math.floor(regionCoords.x)
    self.y = math.floor(regionCoords.y)
    self.danger_cache = DangerCache.new(self)

    return self
end
return RegionClass
