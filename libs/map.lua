require "defines"
local Region = require "libs/region"

Map = {}

function Map.new()
    -- list of regions to scan for biter or spitter spawners. When empty, the map is re-scanned.
    if not global.regionQueue then global.regionQueue = {} end
    -- list of regions scanned
    if not global.visitedRegions then global.visitedRegions = {} end
    -- list of regions with biter or spitter spawners in them
    if not global.enemyRegionQueue then global.enemyRegionQueue = {} end
    -- cache of danger value for region areas.
    if not global.dangerCache then global.dangerCache = {} end
    -- cache of Misanthrope-caused biter attacks for each region
    if not global.previousBiterAttacks then global.previousBiterAttacks = {} end
    -- cache indicates if a region has any entities owned by the player force in them
    if not global.regionHasAnyTargets then global.regionHasAnyTargets = {} end

    local Map = {}

    function Map:tick()
        self:iterateMap()
        self:iterateEnemyRegions()
    end

    BITER_TARGETS = {}
    BITER_TARGETS["big-electric-pole"] = {value = 1000}
    BITER_TARGETS["straight_rail"] = {value = 750}
    BITER_TARGETS["curved_rail"] = {value= 750}
    BITER_TARGETS["medium-electric-pole"] = {value= 250}
    BITER_TARGETS["small-electric-pole"] = {value= 150}

    BITER_TARGETS["rail-signal"] = {value= 500}
    BITER_TARGETS["rail-chain-signal"] = {value= 750}

    BITER_TARGETS["roboport"] = {value= 500}
    BITER_TARGETS["roboportmk2"] = {value= 750}

    BITER_TARGETS["pipe-to-ground"] = {value= 75}
    BITER_TARGETS["pipe"] = {value= 15}

    BITER_TARGETS["express-transport-belt-to-ground"] = {value= 80}
    BITER_TARGETS["fast-transport-belt-to-ground"] = {value= 50}
    BITER_TARGETS["basic-transport-belt-to-ground"] = {value= 30}

    BITER_TARGETS["offshore-pump"] = {value= 150}
    BITER_TARGETS["storage-tank"] = {value= 50}
    
    function Map:reset_danger_cache(position)
        local region = Region.new(position)
        region:getDangerCache():reset(true)
        Logger.log("Reset danger cache for " .. region:tostring())
    end
    
    function Map:get_region(position)
        return Region.new(position)
    end

    function Map:updateRegionAI(region)
        Logger.log("Updating biter AI for " .. region:tostring())
        self:attackTargets(region)
    end

    function Map:attackTargets(region)
        local expansion_phase = BiterExpansion.get_expansion_phase(global.expansion_index)
        
        -- setting highest_value > 0 means don't attack if there are only targets with good defenses
        local highest_value = expansion_phase.minimum_attack_value
        local highest_value_entity = nil
        local any_targets = false
        for entity_name, target_data in pairs(BITER_TARGETS) do
            local targets = region:findEntities({entity_name})
            for i = 1, #targets do
                any_targets = true
                -- danger cache invalidates after 3 hours (or manual invalidation by turrent placement)
                if region:getDangerCache():calculatedAt() == -1 or (game.tick - region:getDangerCache():calculatedAt()) > (60 * 60 * 60 * 3) then
                    Logger.log(region:tostring() .. " - Danger cache recalculating...")
                    region:getDangerCache():calculate()
                    --Logger.log(region:tostring() .. " - Danger cache calculated: " .. region:getDangerCache():tostring())
                end
                
                local value = (target_data.value + math.random(target_data.value)) * 10000
                local defenses = region:getDangerCache():getDanger(targets[i].position)
                local attack_count = region:get_count_attack_on_position(targets[i].position)
                value = value / math.max(1, 1 + defenses)
                value = value / math.max(1, 1 + attack_count)
                -- Logger.log("Potential Target: " .. targets[i].name .. " at position " .. serpent.line(targets[i].position) .. "\n\t\tBase value: " .. target_data.value .. ". Defense level: " .. defenses .. ". Attack count: " .. attack_count .. ". Calculated value: " .. value .. ". Highest value: " .. highest_value)
                if value > highest_value then
                    highest_value = value
                    highest_value_entity = targets[i]
                end
            end
        end
        
        -- cache whether any player-made structures exist in the region, don't bother attacking again until it does
        local index = bit32.bor(bit32.lshift(region:getX(), 16), bit32.band(region:getY(), 0xFFFF))
        global.regionHasAnyTargets[index] = any_targets
        
        if highest_value_entity ~= nil then
            Logger.log("Highest value target: "  .. highest_value_entity.name .. " at position " .. serpent.line(highest_value_entity.position) .. ", with a value of " .. highest_value)
            local unit_count = expansion_phase.min_biter_attack_group + math.random(expansion_phase.min_biter_attack_group / 2)
            local search_distance = expansion_phase.min_biter_search_distance + math.random(32, 64)
            highest_value_entity.surface.set_multi_command({command = {type=defines.command.attack, target=highest_value_entity, distraction=defines.distraction.none}, unit_count = unit_count, unit_search_distance = search_distance})
            region:mark_attack_position(highest_value_entity.position)

            return true
        else
            Logger.log("No valuable targets for " .. region:tostring() .. ". Minimum value was: " .. highest_value)
            return false
        end
    end

    function Map:iterateEnemyRegions()
        -- check and update enemy regions every 5 s in non-peaceful, and every 60s in peaceful
        local frequency = 300
        if global.expansion_state == "Peaceful" then
            frequency = 3600
        end

    	if (game.tick % frequency == 0) then
    		if #global.enemyRegionQueue == 0 then
    			Logger.log("No enemy regions found.")
    		else
                local iterations = math.min(5, #global.enemyRegionQueue)
                for i = 1, iterations do
                    local enemyRegionCoords = table.remove(global.enemyRegionQueue, 1)
                    if enemyRegionCoords == nil then break end
                    
                    local enemyRegion = Region.byRegionCoords(enemyRegionCoords)
                    local index = bit32.bor(bit32.lshift(enemyRegionCoords.x, 16), bit32.band(enemyRegionCoords.y, 0xFFFF))
                    local any_targets = global.regionHasAnyTargets[index] or global.regionHasAnyTargets[index] == nil
                    if not any_targets then
                        Logger.log("No targets available (cache: " .. index .. ") in " .. enemyRegion:tostring())
                    end
                    
        			if any_targets and #enemyRegion:findEntities({"biter-spawner", "spitter-spawner"}) > 0 then
                        global.enemyRegionQueue[#global.enemyRegionQueue + 1] = enemyRegionCoords

                        if global.expansion_state ~= "Peaceful" then
                            self:updateRegionAI(enemyRegion)
                        end
                        break
        			end
                end
    		end
    	end
    end

    function Map:iterateMap()
    	if (game.tick % 120 == 0) then
    		local region = self:nextRegion()

    		if not self:isEnemyRegion(region) and #region:findEntities({"biter-spawner", "spitter-spawner"}) > 0 then
    			global.enemyRegionQueue[#global.enemyRegionQueue + 1] = {x = region:getX(), y = region:getY()}
    		end
    	end
    end

    function Map:seedInitialQueue()
        Logger.log("Seeding initial region queue")

    	-- reset lists
    	global.visitedRegions = {}
    	global.regionQueue = {}

    	for i = 1, #game.players do
    		if game.players[i].connected then
                self:addPartiallyCharted(Region.new(game.players[i].position))
    		end
    	end
    	global.regionQueue[#global.regionQueue + 1] = {x = 0, y = 0}
    end

    function Map:nextRegion()
    	if #global.regionQueue == 0 then
            self:seedInitialQueue()
    	end
    	local nextRegion = Region.byRegionCoords(table.remove(global.regionQueue, 1))

    	self:addPartiallyCharted(nextRegion:offset(1, 0))
        self:addPartiallyCharted(nextRegion:offset(-1, 0))
        self:addPartiallyCharted(nextRegion:offset(0, 1))
        self:addPartiallyCharted(nextRegion:offset(0, -1))

    	global.visitedRegions[#global.visitedRegions + 1] = {x = nextRegion:getX(), y = nextRegion:getY()}

    	return nextRegion
    end

    function Map:isAlreadyIterated(region)
    	for i = 1, #global.visitedRegions do
    		if (global.visitedRegions[i].x == region:getX() and global.visitedRegions[i].y == region:getY()) then
    			return true
    		end
    	end
    	return false
    end

    function Map:isPendingIteration(region)
    	for i = 1, #global.regionQueue do
    		if (global.regionQueue[i].x == region:getX() and global.regionQueue[i].y == region:getY()) then
    			return true
    		end
    	end
    	return false
    end

    function Map:isEnemyRegion(region)
    	for _, enemyRegion in pairs(global.enemyRegionQueue) do
    		if (enemyRegion.x == region:getX() and enemyRegion.y == region:getY()) then
    			return true
    		end
    	end
    	return false
    end

    function Map:addPartiallyCharted(region)
    	if not (self:isAlreadyIterated(region) or self:isPendingIteration(region)) then
    		if region:isPartiallyCharted() then
    			global.regionQueue[#global.regionQueue + 1] = {x = region:getX(), y = region:getY()}
    		else
    			-- don't recheck if partially charted over and over in the future, just add to 'visited list'
    			global.visitedRegions[#global.visitedRegions + 1] = {x = region:getX(), y = region:getY()}
    		end
    	end
    end
    return Map
end

return Map
