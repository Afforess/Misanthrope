require "defines"
local linked_list = require "libs/linked_list"
local Region = require "libs/region"

Map = {}

function Map.new(logger)
    if not global.regionQueue then
        global.regionQueue = {}
    end
    if not global.visitedRegions then
        global.visitedRegions = {}
    end
    if not global.powerLineTargets then
        global.powerLineTargets = {}
    end
    if not global.powerShorts then
        global.powerShorts = {}
    end
    if not global.powerShorts then
        global.powerShorts = {}
    end
    global.enemyRegions = nil

    local Map = { l = logger, enemyRegions = linked_list()}

    function Map:tick()
        self:iterateMap()
        self:iterateEnemyRegions()
        if game.tick % 3600 == 0 then
            self:updatePowerLines()
        end

        if game.tick % 60 == 0 then
            self:checkPowerLinesForShorts()
        end

        self:updatePowerShorts()
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
    BITER_TARGETS["basic-transport-belt-to-ground"] = {value= 30}

    BITER_TARGETS["offshore-pump"] = {value= 150}
    BITER_TARGETS["storage-tank"] = {value= 50}

    function Map:updateRegionAI(region, recursive)
        self.l:log("Updating biter AI for " .. region:tostring())

        if not self:attackTargets(region) then
            self.l:log("No targets found!")
            if not recursive then
                --self:updateRegionAI(region:offset(0, 1), true)
                --self:updateRegionAI(region:offset(0, -1), true)
                --self:updateRegionAI(region:offset(1, 0), true)
                --self:updateRegionAI(region:offset(-1, 0), true)
            end
        end
    end

    function Map:attackTargets(region)
        -- setting highest_value > 0 means don't attack if there are only targets with good defenses
        local highest_value = 10000
        local highest_value_entity = nil
        for entity_name, target_data in pairs(BITER_TARGETS) do
            local targets = region:findEntities({entity_name})
            for i = 1, #targets do
                if region:getDangerCache():calculatedAt() == -1 or (game.tick - region:getDangerCache():calculatedAt()) > (60 * 60 * 10) then
                    region:getDangerCache():calculate()
                    --self.l:log(region:tostring() .. " - Danger cache calculated: " .. region:getDangerCache():tostring())
                end
                
                local value = target_data.value * 10000
                local defenses = region:getDangerCache():getDanger(targets[i].position)
                local attack_count = region:get_count_attack_on_position(targets[i].position)
                value = value / math.max(1, 1 + defenses)
                value = value / math.max(1, 1 + attack_count)
                self.l:log("Potential Target: " .. targets[i].name .. " at position " .. self.l:toString(targets[i].position) .. ". Base value: " .. target_data.value .. ". Defense level: " .. defenses .. ". Attack count: " .. attack_count .. ". Calculated value: " .. value .. ". Highest value: " .. highest_value)
                if value > highest_value then
                    highest_value = value
                    highest_value_entity = targets[i]
                end
            end
        end
        if highest_value_entity ~= nil then
            if highest_value_entity.type == "electric-pole" then
                self:trackPowerLine(highest_value_entity)
            end
            self.l:log("Region attacked_positions: " .. self.l:toString(region.attacked_positions))
            self.l:log("Highest value target: "  .. highest_value_entity.name .. " at position " .. self.l:toString(highest_value_entity.position) .. ", with a value of " .. highest_value)
            highest_value_entity.surface.set_multi_command({command = {type=defines.command.attack, target=highest_value_entity, distraction=defines.distraction.none}, unit_count = math.random(10, 50) + 1, unit_search_distance = 32 + math.random(64, 128)})
            region:mark_attack_position(highest_value_entity.position, self.l)

            return true
        else
            self.l:log("No valuable targets.")
            return false
        end
    end

    function Map:trackPowerLine(entity)
        for i = 1, #global.powerLineTargets do
            if global.powerLineTargets[i].entity == entity then
                return false
            end
        end
        global.powerLineTargets[#global.powerLineTargets + 1] = {entity = entity, age = game.tick}
        return true
    end

    function Map:checkPowerLinesForShorts()
        for i = 1, #global.powerLineTargets do
            if global.powerLineTargets[i] ~= nil and global.powerLineTargets[i].entity ~= nil and global.powerLineTargets[i].entity.valid then
                local powerLine = global.powerLineTargets[i].entity
                local enemies = powerLine.surface.find_enemy_units(powerLine.position, 2)
                self.l:log(#enemies .. " Nearby enemies to powerline at " .. self.l:toString(powerLine.position))
                if #enemies > 0 then
                    local roll = math.random(1000)
                    if game.darkness > 0.5 then
                        roll = math.random(500)
                    end
                    self.l:log("Rolled a " .. roll .. " to short out power lines")
                    if roll < 10 then
                        local position = {x = powerLine.position.x + 0.5, y = powerLine.position.y + 0.5}
                        local powerShort = powerLine.surface.create_entity({name = "power-short", position = position, force = powerLine.force})
                        global.powerShorts[#global.powerShorts + 1] = {entity = powerShort, ticks_left = math.random(6, 25)}
                        
                        -- create a duplicate power line entity and explode it immediately for the animation
                        local animation = powerLine.surface.create_entity({name = powerLine.name, position = powerLine.position, force = powerLine.force})
                        if animation ~= nil then
                            animation.die()
                        end
                    end
                end
            end
        end
    end

    function Map:updatePowerShorts()
        if #global.powerShorts > 0 then
            local valid = {}
            for i = 1, #global.powerShorts do
                local short = global.powerShorts[i]
                if short ~= nil and short.entity ~= nil and short.entity.valid then
                    short.ticks_left = short.ticks_left - 1
                    if short.ticks_left > 1 then
                        valid[#valid + 1] = short
                    else
                        short.entity.destroy()
                    end
                end
            end
            global.powerShorts = valid
        end
    end

    -- removes any invalid lines
    function Map:updatePowerLines()
        local valid = {}
        for i = 1, #global.powerLineTargets do
            if global.powerLineTargets[i] ~= nil and global.powerLineTargets[i].entity ~= nil and global.powerLineTargets[i].entity.valid then
                -- don't track lines older than 5 min
                if math.abs(game.tick - global.powerLineTargets[i].age) < 18000 then
                    valid[#valid + 1] = global.powerLineTargets[i]
                end
            end
        end
        global.powerLineTargets = valid
    end

    function Map:iterateEnemyRegions()
        -- check and update enemy regions every 10 s in non-peaceful, and every 30s in peaceful
        local frequency = 600
        if global.expansion_state == "peaceful" then
            frequency = 30 * 60
        end

    	if (game.tick % frequency == 0) then
    		local enemyRegion = self.enemyRegions:pop_front()
    		if enemyRegion == nil then
    			self.l:log("No enemy regions found.")
    		else
    			if #enemyRegion:findEntities({"biter-spawner", "spitter-spawner"}) == 0 then
    				-- enemy spawners have been destroyed
                    self.l:log(enemyRegion:tostring() .. " no longer has enemy spawners. Removing from list of enemy regions.")
    			else
    				-- add back to end of linked list
    				self.enemyRegions:push_back(enemyRegion)

                    if global.expansion_state ~= "Peaceful" then
                        self:updateRegionAI(enemyRegion, false)
                    end
    			end
    		end
    	end
    end

    function Map:iterateMap()
    	if (game.tick % 30 == 0) then
    		local region = self:nextRegion()

    		if not self:isEnemyRegion(region) and #region:findEntities({"biter-spawner", "spitter-spawner"}) > 0 then
    			self.enemyRegions:push_back(region)
    		end
    	end
    end

    function Map:seedInitialQueue()
        self.l:log("Seeding initial region queue")

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
    	for enemyRegion in self.enemyRegions:iterate() do
    		if (enemyRegion:getX() == region:getX() and enemyRegion:getY() == region:getY()) then
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
