require 'libs/pathfinder'

region_attack_plan = {}
region_attack_plan.__index = region_attack_plan

-- Returns how computed computationally expensive tick was
function region_attack_plan.tick(attack_data)
    if attack_data.completed then
        return 0
    end
    local region_data = attack_plan.get_region(attack_data)
    if not region_data then
        attack_plan.complete_plan(attack_data)
        return 0
    end

    -- Find a place to attack
    if attack_data.search then
        if true then return 0 end
        local search = math.min(50, #attack_data.search.chunks)
        for i = 1, search do
            if #attack_data.search.chunks == 1 then
                break
            end
            attack_plan.do_target_search(attack_data)
        end
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
            --check to see if we ever actually attacked or if this attack never left to go to the target
            if not attack_data.attack_ever_began then
                local state = attack_data.unit_group.state
                attack_data.attack_ever_began = (state == defines.groupstate.attacking_distraction or state == defines.groupstate.attacking_target)
            end
        else
            attack_plan.complete_plan(attack_data)
        end
        -- 3 minutes
        if attack_data.attack_tick + (60 * 60 * 60 * 3) > game.tick then
            attack_plan.complete_plan(attack_data)
        end
    else
        region_attack_plan.coordinate_biters(attack_data)
        return 20
    end

    return 0
end

function region_attack_plan.coordinate_biters(attack_data)
    local expansion_phase = BiterExpansion.get_expansion_phase(global.expansion_index)
    local surface = game.surfaces[attack_data.surface_name]
    local pos = attack_data.position
    local region_data = attack_plan.get_region(attack_data)
    local region_area = region.region_area(region_data, 0)
    local enemy_units = surface.find_entities_filtered({area = region_area, type = "unit", force = game.forces.enemy})

    if #enemy_units == 0 then
        attack_data.completed = true
        return
    end

    local total_x = 0
    local total_y = 0
    for _, entity in pairs(enemy_units) do
        local entity_pos = entity.position
        total_x = total_x + entity_pos.x
        total_y = total_y + entity_pos.y
    end
    local avg_pos = {x = total_x / #enemy_units, y = total_y / #enemy_units}

    local safe_pos = surface.find_non_colliding_position("behemoth-spitter", avg_pos, 16, 0.5)
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
    unit_group.set_command(command)
    unit_group.start_moving()
    attack_data.attack_tick = game.tick
end

function region_attack_plan.new(surface_name, position, region_key)
    return { class = "region_attack_plan", position = position, surface_name = surface_name, region_key = region_key, completed = false }
end
