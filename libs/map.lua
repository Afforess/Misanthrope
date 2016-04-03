require "libs/region"
require "libs/biter_targets"
require "libs/ai/attack_plan"
require "libs/ai/region_attack_plan"

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

    if not global.attack_plans_list then
        global.attack_plans_list = {}
        for i = 0, 300 do
            global.attack_plans_list[i] = {}
        end
    end
    if not global.attack_plans_naunce then global.attack_plans_naunce = 0 end

    if not global.naunce then global.naunce = 0 end
    if not global.biter_scents then global.biter_scents = {} end

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
    global.foo = nil
    global.bar = nil
    global.iteration_phase = nil
    global.attack_plans_queue = nil
    global.attack_plans_queue_idx = nil

    if not global.migrated_keys then
        global.migrated_keys = true

        local region_queue = {}
        for _, region_data in pairs(global.region_queue) do
            table.insert(region_queue, region.region_key(region_data))
        end
        global.region_queue = region_queue

        local visited_regions = {}
        for _, region_data in pairs(global.visited_regions) do
            visited_regions[region.region_key(region_data)] = true
        end
        global.visited_regions = visited_regions

        local enemy_regions = {}
        for _, region_data in pairs(global.enemy_regions) do
            table.insert(enemy_regions, region.region_key(region_data))
        end
        global.enemy_regions = enemy_regions

        Logger.log("Migrated reqion queue structures")
    end

    for _, region_data in pairs(global.regions) do
        region.migrate_regions(region_data)
    end

    -- migrate all attack plans w/o class name
    if global.attack_plans then
        for key, plans in pairs(global.attack_plans) do
            for _, plan in pairs(plans) do
                if not plan.class then
                    plan.class = "attack_plan"
                    plan.attack_tick = 0
                    table.insert(global.attack_plans_list[global.attack_plans_naunce], plan)
                    global.attack_plans_naunce = (global.attack_plans_naunce + 1) % 300
                end
            end
        end

        global.attack_plans = nil
    end

    local Map = {}

    function Map:tick()
        self:spread_biter_scents()
        self:iterate_map()
        self:iterate_enemy_regions()
        self:tick_attack_plans()
    end

    function Map:tick_attack_plans()
        if global.toggle_attack_plans then
            return
        end
        local compute_expense = 0
        local expansion_phase = BiterExpansion.get_expansion_phase(global.expansion_index)
        local max_compute = expansion_phase.compute_time
        --Abort all attack plans in peaceful
        if max_compute == 0 and not global.plans_cleared then
            global.plans_cleared = true
            for i = 0, 300 do
                global.attack_plans_list[i] = {}
            end
            return
        end
        global.plans_cleared = nil

        local count = 0
        local plans = global.attack_plans_list[game.tick % 300]
        for i = 1, #plans do
            local plan = plans[i]

            -- update the attack plan!
            _G[plan.class].tick(plan)
            if not plan.completed then
                count = count + 1
            end
        end

        for i = #plans, 1, -1 do
            local plan = plans[i]
            if plan.completed then
                table.remove(plans, i)
            end
        end
    end

    function Map:any_attack_plans(region_key)
        local list = global.attack_plans_list
        for i = 0, 300 do
            local plans = list[i]
            for i = 1, #plans do
                local plan = plans[i]
                if plan.region_key == region_key then
                    return true
                end
            end
        end
        return false
    end

    function Map:spread_biter_scents()
        local idx = game.tick % 3600
        local scents = global.biter_scents[idx]
        if scents then
            for i = 1, #scents do
                biter_scents.tick(scents[i])
            end
        end
    end

    function Map:update_region_ai(region_data)
        local plan_key = region.region_key(region_data)
        if self:any_attack_plans(plan_key) then
            Logger.log("Not scheduling another attack plan, " .. plan_key .. " already has an active attack plan")
        end
        region.update_biter_base_locations(region_data)
        if #region_data.enemy_bases > 0 then
            region_attack_plans = {}
            local expansion_phase = BiterExpansion.get_expansion_phase(global.expansion_index)
            local rand = math.random(0, 100)
            if rand < expansion_phase.region_attack_chance then
                local largest_base = nil
                for _, base in pairs(region_data.enemy_bases) do
                    if largest_base == nil or largest_base.count < base.count then
                        largest_base = base
                    end
                end

                local plan = region_attack_plan.new(region_data.surface_name, largest_base.position, region.region_key(region_data))
                --table.insert(global.attack_plans_list[global.attack_plans_naunce], plan)
                global.attack_plans_naunce = (global.attack_plans_naunce + 1) % 300
                Logger.log("Created a new region-wide attack plan (" .. plan_key .. ")")
            else
                local new_plans = 0
                for _, base in pairs(region_data.enemy_bases) do
                    local plan = attack_plan.new(region_data.surface_name, base.position, region.region_key(region_data), base)
                    table.insert(global.attack_plans_list[global.attack_plans_naunce], plan)
                    global.attack_plans_naunce = (global.attack_plans_naunce + 1) % 300
                    new_plans = new_plans + 1
                end
                Logger.log("Created new region attack plans (" .. plan_key .. "): " .. new_plans)
            end
        end
        return true
    end

    function Map:iterate_enemy_regions()
        local expansion_phase = BiterExpansion.get_expansion_phase(global.expansion_index)
        local frequency = expansion_phase.region_update_frequency

        if (game.tick % frequency == 0) then
            if #global.enemy_regions == 0 then
                Logger.log("No enemy regions found.")
            else
                Logger.log("Current enemy regions: " .. serpent.line(global.enemy_regions, {comment = false}))
                local enemy_region_key = table.remove(global.enemy_regions, 1)
                local enemy_region = global.regions[enemy_region_key]

                Logger.log("")
                Logger.log("Checking enemy region: " .. region.tostring(enemy_region))
                if region.update_biter_base_locations(enemy_region) and region.any_potential_targets(enemy_region, 12) then
                    -- add back to the end of the list
                    table.insert(global.enemy_regions, enemy_region_key)

                    if game.peaceful_mode then
                        return
                    end
                    Logger.log("Updating enemy region ai: " .. region.tostring(enemy_region))
                    self:update_region_ai(enemy_region)
                end
                Logger.log("Number of enemy regions: " .. #global.enemy_regions)
                Logger.log("")

            end
        end
    end

    function Map:iterate_map()
        if (game.tick % 120 == 0) then
            local region_data = self:next_region(true)
            region.update_player_target_cache(region_data)
            Logger.log("Iterating map, region: " .. region.tostring(region_data))
            if not self:is_enemy_region(region_data) and (region.update_biter_base_locations(region_data) and region.any_potential_targets(region_data, 12)) then
                Logger.log("Found enemy region: " .. region.tostring(region_data))
                table.insert(global.enemy_regions, region.region_key(region_data))
            end
        end
    end

    function Map:seed_initial_values()
        Logger.log("Seeding initial region values")

        -- reset lists
        global.visited_regions = {}
        global.region_queue = {}

        for i = 1, #game.players do
            if game.players[i].connected then
                self:add_partially_charted(region.lookup_region_from_position(game.players[i].surface, game.players[i].position))
            end
        end
        table.insert(global.region_queue, region.lookup_region_key(game.surfaces.nauvis.name, 0, 0))
    end

    function Map:next_region(remove)
        if #global.region_queue == 0 then
            self:seed_initial_values()
        end

        local next_region_key = global.region_queue[1]
        local next_region = global.regions[next_region_key]
        if remove then
           table.remove(global.region_queue, 1)

            self:add_partially_charted(region.offset(next_region, 1, 0))
            self:add_partially_charted(region.offset(next_region, -1, 0))
            self:add_partially_charted(region.offset(next_region, 0, 1))
            self:add_partially_charted(region.offset(next_region, 0, -1))

            global.visited_regions[region.region_key(next_region)] = true
        end

        return next_region
    end

    function Map:is_already_iterated(region_data)
        return global.visited_regions[region.region_key(region_data)]
    end

    function Map:is_pending_iteration(region_data)
        local region_key = region.region_key(region_data)
        for i = 1, #global.region_queue do
            if (global.region_queue[i] == region_key) then
                return true
            end
        end
        return false
    end

    function Map:is_enemy_region(region_data)
        local region_key = region.region_key(region_data)
        for _, enemy_region_key in pairs(global.enemy_regions) do
            if region_key == enemy_region_key then
                return true
            end
        end
        return false
    end

    function Map:add_partially_charted(region_data)
        if not (self:is_already_iterated(region_data) or self:is_pending_iteration(region_data)) then
            if region.is_partially_charted(region_data) then
                table.insert(global.region_queue, region.region_key(region_data))
            else
                -- don't recheck if partially charted over and over in the future, just add to 'visited list'
                global.visited_regions[region.region_key(region_data)] = true
            end
        end
    end
    return Map
end

return Map
