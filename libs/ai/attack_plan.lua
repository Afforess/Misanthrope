require 'libs/pathfinder'

attack_plan = {}
attack_plan.__index = attack_plan

function attack_plan.get_region(attack_data)
    return global.regions[attack_data.region_key]
end

function attack_plan.begin_target_search(attack_data)
    local expansion_phase = BiterExpansion.get_expansion_phase(global.expansion_index)
    local max_chunks = expansion_phase.min_biter_attack_chunk_distance

    local chunks = {}
    for dx = -(max_chunks), max_chunks do
        for dy = -(max_chunks), max_chunks do
            table.insert(chunks, {dx = dx, dy = dy})
        end
    end
    local search_data = {chunks = chunks, best_value = nil, best_position = nil}
    attack_data.search = search_data
end

function attack_plan.do_target_search(attack_data, max_chunks)
    local chunk = table.remove(attack_data.search.chunks, 1)
    local dx = chunk.dx
    local dy = chunk.dy
    local tile_x = dx * 32 + attack_data.position.x
    local tile_y = dx * 32 + attack_data.position.y
    
    local region_data = attack_plan.get_region(attack_data)
    local value = region.get_player_target_value_at(region_data, tile_x, tile_y)
    value = value / (1 + ((dx * dx) + (dy * dy)))

    if region_data.poor_attack_targets then
        for _, pos in pairs(region_data.poor_attack_targets) do
            local pos_x = pos.x
            local pos_y = pos.y
            
            local axbx = (pos_x - tile_x)
            local ayby = (pos_y - tile_y)
            local dist_squared = axbx * axbx + ayby * ayby
            
            if dist_squared <= 1024 then
                value = math.max(1, math.floor(value / 4))
            elseif dist_squared <= 4096 then
                value = math.max(1, math.floor(value / 2))
            end
        end
    end
    if value > 0 and (attack_data.search.best_value == nil or value > attack_data.search.best_value)then
        attack_data.search.best_value = value
        attack_data.search.best_position = { x = tile_x, y = tile_y }
    end

    return #attack_data.search.chunks == 0
end

-- Returns how computed computationally expensive tick was (0 - almost free, 10 - very expensive)
function attack_plan.tick(attack_data)
    if attack_data.completed then
        return 0
    end

    -- Find a place to attack
    if attack_data.search then
        if attack_plan.do_target_search(attack_data) then
            if attack_data.search.best_position == nil then
                attack_plan.complete_plan(attack_data)
            else
                attack_data.target_position = attack_data.search.best_position
                attack_data.search = nil
            end
        end
        return 1
    elseif not attack_data.target_position then
        attack_plan.begin_target_search(attack_data)
        return 1
    end

    if attack_data.unit_group and not attack_data.wait_for_attack then
        if attack_data.unit_group.valid then
            attack_data.attack_in_progress = attack_data.attack_in_progress + 1
            --check to see if we ever actually attacked or if this attack never left to go to the target
            if not attack_data.attack_ever_began and game.tick % 10 == 0 then
                local state = attack_data.unit_group.state 
                attack_data.attack_ever_began = (state == defines.groupstate.attacking_distraction or state == defines.groupstate.attacking_target)
            end
        else
            Logger.log("Took " .. attack_data.attack_in_progress .. " ticks for the unit group to become invalid (attack complete)")
            attack_plan.complete_plan(attack_data)
        end
        -- 1 minute
        if attack_data.attack_in_progress > (60 * 60 * 60 * 1) then
            Logger.log("Attack unit group never become invalid! Data: {" .. serpent.line(attack_data) .. "}")
            attack_plan.complete_plan(attack_data)
        end
    else
        attack_plan.coordinate_biters(attack_data)
        return 5
    end
    
    return 0
end

function attack_plan.complete_plan(attack_data)
    attack_data.completed = true
    local target_pos = attack_data.target_position
    if target_pos and not attack_data.attack_ever_began then
        Logger.log("Attack targeted position but never began")
        local region_data = attack_plan.get_region(attack_data)
        if not region_data.poor_attack_targets then
            region_data.poor_attack_targets = {}
        end
        local found = false
        for _, pos in pairs(region_data.poor_attack_targets) do
            if pos.x == target_pos.x and pos.y == target_pos.y then
                found = true
                break
            end
        end
        if not found then
            table.insert(region_data.poor_attack_targets, target_pos)
        end
    end
end

function attack_plan.coordinate_biters(attack_data)
    local expansion_phase = BiterExpansion.get_expansion_phase(global.expansion_index)
    local surface = game.surfaces[attack_data.surface_name]
    local pos = attack_data.position
    local range = math.min(35, 15 + (3 * attack_data.biter_base.count))
    local area = {left_top = {x = pos.x - range, y = pos.y - range}, right_bottom = {x = pos.x + range, y = pos.y + range}}
    local enemy_units = surface.find_entities_filtered({area = area, type = "unit", force = game.forces.enemy})
    
    if #enemy_units == 0 then
        Logger.log("Failed to find any enemy units at " .. serpent.line(pos, {comment = false}))
        attack_data.completed = true
        return
    end

    Logger.log("Found " .. #enemy_units .. " enemy units at " .. serpent.line(pos, {comment = false}))
    local total_x = 0
    local total_y = 0
    for _, entity in pairs(enemy_units) do
        local entity_pos = entity.position
        total_x = total_x + entity_pos.x
        total_y = total_y + entity_pos.y
    end
    local avg_pos = {x = total_x / #enemy_units, y = total_y / #enemy_units}
    Logger.log("Average biter position for attack position (" .. serpent.line(pos, {comment = false}) .. "): " .. serpent.line(avg_pos, {comment = false}))

    local safe_pos = surface.find_non_colliding_position("behemoth-spitter", avg_pos, 16, 0.5)
    Logger.log("Safe position for grouping: " .. serpent.line(safe_pos, {comment = false}))
    if not safe_pos then
        attack_data.completed = true
        return
    end

    local unit_group = surface.create_unit_group({position = safe_pos, force = game.forces.enemy})
    for _, entity in pairs(enemy_units) do
        unit_group.add_member(entity)
    end
    attack_data.unit_group = unit_group
    attack_data.attack_in_progress = 0
    local command = {type = defines.command.attack_area, destination = attack_data.target_position, radius = 16, distraction = defines.distraction.by_damage}

    if game.evolution_factor > 0.5 and #enemy_units < 20 and math.random() < 0.5 then
        local target_pos = attack_data.target_position
        local half_way_pos = { x = (safe_pos.x + target_pos.x) / 2, y = (safe_pos.y + target_pos.y) / 2} 
        local safe_base_pos = surface.find_non_colliding_position("behemoth-spitter", half_way_pos, 16, 0.5)
        Logger.log("Safe position for building a new base: " .. serpent.line(safe_base_pos, {comment = false}))
        if safe_base_pos then
            command = {type = defines.command.build_base, destination = safe_base_pos, ignore_planner = 1, distraction = defines.distraction.by_damage}
        end
    end

    Logger.log("Command: " .. serpent.line(command, {comment=false}))
    unit_group.set_command(command)
    unit_group.start_moving()
end

function attack_plan.new(surface_name, position, region_key, biter_base)
    return { position = position, surface_name = surface_name, region_key = region_key, biter_base = biter_base, completed = false }
end
