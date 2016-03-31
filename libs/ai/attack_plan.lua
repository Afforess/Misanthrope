require 'libs/pathfinder'

attack_plan = {}
attack_plan.__index = attack_plan

function attack_plan.find_best_player_target(attack_data, max_chunks)
    local best_value = nil
    local best_position = nil
    local surface = game.surfaces[attack_data.surface_name]
    local region_data = region.lookup_region_from_position(surface, attack_data.position)

    for dx = -(max_chunks), max_chunks do
        for dy = -(max_chunks), max_chunks do
            local tile_x = dx * 32 + attack_data.position.x
            local tile_y = dx * 32 + attack_data.position.y

            local value = region.get_player_target_value_at(region_data, {x = tile_x, y = tile_y})
            value = value / (1 + ((dx * dx) + (dy * dy)))
            if value > 0 and (best_value == nil or value > best_value)then
                best_value = value
                best_position = { x = tile_x, y = tile_y }
            end
        end
    end
    
    return best_position
end

function attack_plan.tick(attack_data)
    if attack_data.completed then
        return
    end
    local expansion_phase = BiterExpansion.get_expansion_phase(global.expansion_index)

    if not attack_data.target_position then
        local chunk_search = expansion_phase.min_biter_attack_chunk_distance
        local attack_target = attack_plan.find_best_player_target(attack_data, chunk_search)
        if attack_target == nil then
            Logger.log("Failed to find an attack target within " .. chunk_search .. " chunks of " .. serpent.line(attack_data.position))
            attack_data.completed = true
            return
        else
            Logger.log("Best attack target within " .. chunk_search .. " chunks of " .. serpent.line(attack_data.position) .. " is " .. serpent.line(attack_target))
            attack_data.target_position = attack_target
        end
    end

    if attack_data.unit_group and not attack_data.wait_for_attack then
        if attack_data.unit_group.valid then
            attack_data.attack_in_progress = attack_data.attack_in_progress + 1
            --TODO: track state and stop attacking locations that never generate attack state of 2 or 3 (1 -> 4 == never reached target).
            if attack_data.attack_in_progress % 60 == 0 then
                Logger.log("Unit group attack at (" .. serpent.line(attack_data.region_key, {comment = false}) .. ") in progress, state: " .. attack_data.unit_group.state)
            end
        else
            attack_data.completed = true
            Logger.log("Took " .. attack_data.attack_in_progress .. " ticks for the unit group to become invalid (attack complete)")
        end
        -- 1 minute
        if attack_data.attack_in_progress > (60 * 60 * 60 * 1) then
            Logger.log("Attack unit group never become invalid! Data: {" .. serpent.line(attack_data) .. "}")
            attack_data.completed = true
        end
        return
    else
        attack_plan.coordinate_biters(attack_data)
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
