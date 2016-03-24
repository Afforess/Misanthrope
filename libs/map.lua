require "libs/region"
require "libs/biter_targets"

Map = {}

function Map.new()
    -- table with all regions
    if not global.regions then global.regions = {} end
    -- list of regions to scan for biter or spitter spawners. When empty, the map is re-scanned.
    if not global.region_queue then global.region_queue = {} end
    -- list of regions scanned
    if not global.visited_regions then global.visited_regions = {} end
    -- list of regions with biter or spitter spawners in them
    if not global.enemy_regions then global.enemy_regions = {} end
    global.enemyRegions = nil
    global.powerShorts = nil
    global.powerLineTargets = nil
    global.regionHasAnyTargets = nil
    global.region_has_any_targets = nil
    global.dangerCache = nil
    global.previousBiterAttacks = nil
    global.regionQueue = nil
    global.visitedRegions = nil
    global.enemyRegionQueue = nil
    local Map = {}

    function Map:tick()
        self:iterate_map()
        self:iterate_enemy_regions()
    end

    function Map:update_region_ai(region_data)
        if region.any_potential_targets(region_data, 1) then
            Logger.log("Updating biter AI for " .. region.tostring(region_data))
            self:attack_targets(region_data)
            return true
        end
        return false
    end

    function Map:attack_targets(region_data)
        local expansion_phase = BiterExpansion.get_expansion_phase(global.expansion_index)

        -- setting highest_value > 0 means don't attack if there are only targets with good defenses
        local highest_value = expansion_phase.minimum_attack_value
        local highest_value_entity = nil
        local any_targets = false
        local enemy_force = game.forces.enemy
        local neutral_force = game.forces.neutral
        local search_distance = expansion_phase.min_biter_search_distance + math.random(32, 64)
        local surface = region.get_surface(region_data)

        for _, biter_base in pairs(region_data.enemy_bases) do
            local search_area = {left_top =     {x = biter_base.position.x - search_distance, y = biter_base.position.y - search_distance},
                                 right_bottom = {x = biter_base.position.y + search_distance, y = biter_base.position.y + search_distance}}
            
            for entity_name, target_data in pairs(BITER_TARGETS) do
                local targets = surface.find_entities_filtered({area = search_area, name = entity_name})
                for i = 1, #targets do
                    local force = targets[i].force
                    if force ~= enemy_force and force ~= neutral_force then
                        any_targets = true

                        local value = (target_data.value + math.random(target_data.value)) * 10000 * biter_base.count
                        local defenses = region.get_danger_at(region_data, targets[i].position) * target_data.danger_modifier
                        local attack_count = region.count_attacks_on_position(region_data, targets[i].position)
                        value = value / math.max(1, 1 + defenses)
                        value = value / math.max(1, 1 + attack_count)
                        -- Logger.log("Biter base (" .. serpent.line(biter_base) .. ") found potential target: " .. targets[i].name .. " at position " .. serpent.line(targets[i].position) .. "\n\t\tBase value: " .. target_data.value .. ". Defense level: " .. defenses .. ". Attack count: " .. attack_count .. ". Calculated value: " .. value .. ". Highest value: " .. highest_value)
                        if value > highest_value then
                            highest_value = value
                            highest_value_entity = targets[i]
                        end
                    end
                end
            end
        end

        -- cache whether any player-made structures exist in the region, don't bother attacking again until it does
        region_data.any_targets = any_targets

        if highest_value_entity ~= nil then
            Logger.log("Highest value target: "  .. highest_value_entity.name .. " at position " .. serpent.line(highest_value_entity.position) .. ", with a value of " .. highest_value)
            local unit_count = expansion_phase.min_biter_attack_group + math.random(expansion_phase.min_biter_attack_group / 2)
            surface.set_multi_command({command = {type=defines.command.attack, target=highest_value_entity, distraction=defines.distraction.none}, unit_count = unit_count, unit_search_distance = search_distance})
            region.mark_attack_position(region_data, highest_value_entity.position)

            return true
        else
            Logger.log("No valuable targets for " .. region.tostring(region_data) .. ". Minimum value was: " .. highest_value)
            return false
        end
    end

    function Map:iterate_enemy_regions()
        -- check and update enemy regions every 5 s in non-peaceful, and every 60s in peaceful
        local frequency = 300
        if global.expansion_state == "Peaceful" then
            frequency = 3600
        end

    	if (game.tick % frequency == 0) then
    		if #global.enemy_regions == 0 then
    			Logger.log("No enemy regions found.")
    		else
                local iterations = math.min(5, #global.enemy_regions)
                for i = 1, iterations do
                    local enemy_region = table.remove(global.enemy_regions, 1)
                    if enemy_region == nil then break end

                    Logger.log("Checking enemy region: " .. region.tostring(enemy_region))
        			if region.update_biter_base_locations(enemy_region) then
                        -- add back to the end of the list
                        table.insert(global.enemy_regions, enemy_region)

                        if global.expansion_state == "Peaceful" then
                            break
                        end
                        Logger.log("Updating enemy region ai: " .. region.tostring(enemy_region))
                        if self:update_region_ai(enemy_region) then
                            break
                        end
        			end
                end
    		end
    	end
    end

    function Map:iterate_map()
    	if (game.tick % 150 == 0) then
    		local region_data = self:next_region()

            Logger.log("Iterating map, region: " .. region.tostring(region_data))
    		if not self:is_enemy_region(region_data) and region.update_biter_base_locations(region_data) then
                Logger.log("Found enemy region: " .. region.tostring(region_data))
    			table.insert(global.enemy_regions, region_data)
    		end
    	end
    end

    function Map:seed_initial_values()
        Logger.log("Seeding initial region values")

    	-- reset lists
    	global.visited_regions = {}
    	global.region_queue = {}
        global.enemy_regions = {}

    	for i = 1, #game.players do
    		if game.players[i].connected then
                self:add_partially_charted(region.lookup_region_from_position(game.players[i].surface, game.players[i].position))
    		end
    	end
    	table.insert(global.region_queue, region.lookup_region(game.surfaces.nauvis.name, 0, 0))
    end

    function Map:next_region()
    	if #global.region_queue == 0 then
            self:seed_initial_values()
    	end
        --Logger.log("Region queue: " .. serpent.line(global.region_queue))
        --Logger.log("Visited Regions: " .. serpent.line(global.visited_regions))
        --Logger.log("Enemy Regions: " .. serpent.line(global.enemy_regions))

    	local next_region = table.remove(global.region_queue, 1)

    	self:add_partially_charted(region.offset(next_region, 1, 0))
        self:add_partially_charted(region.offset(next_region, -1, 0))
        self:add_partially_charted(region.offset(next_region, 0, 1))
        self:add_partially_charted(region.offset(next_region, 0, -1))

    	table.insert(global.visited_regions, next_region)

    	return next_region
    end

    function Map:is_already_iterated(region_data)
    	for i = 1, #global.visited_regions do
    		if (global.visited_regions[i].x == region_data.x and global.visited_regions[i].y == region_data.y) then
    			return true
    		end
    	end
    	return false
    end

    function Map:is_pending_iteration(region_data)
    	for i = 1, #global.region_queue do
    		if (global.region_queue[i].x == region_data.x and global.region_queue[i].y == region_data.y) then
    			return true
    		end
    	end
    	return false
    end

    function Map:is_enemy_region(region_data)
    	for _, enemy_region in pairs(global.enemy_regions) do
    		if (enemy_region.x == region_data.x and enemy_region.y == region_data.y) then
    			return true
    		end
    	end
    	return false
    end

    function Map:add_partially_charted(region_data)
    	if not (self:is_already_iterated(region_data) or self:is_pending_iteration(region_data)) then
    		if region.is_partially_charted(region_data) then
    			table.insert(global.region_queue, region_data)
    		else
    			-- don't recheck if partially charted over and over in the future, just add to 'visited list'
    			table.insert(global.visited_regions, region_data)
    		end
    	end
    end
    return Map
end

return Map
