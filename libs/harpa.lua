require "defines"

Harpa = {}

function Harpa.register(entity, player_idx)
    if not global.harpa_list then
        global.harpa_list = {}
    end
    if not global.biter_ignore_list then
        global.biter_ignore_list = {}
    end
    if not global.harpa_overlays then
        global.harpa_overlays = {}
    end
    if player_idx then
        Harpa.create_overlay(entity, player_idx)
    end
    table.insert(global.harpa_list, entity)
end

function Harpa.create_overlay(entity, player_idx)
    -- only allow 1 active overlay per player (to prevent lag)
    for i = #global.harpa_overlays, 1, -1 do
        local overlay = global.harpa_overlays[i]
        if overlay.player_idx == player_idx then
            overlay.ticks_remaining = -1
        end
    end
    local overlay_entity = entity.surface.create_entity({name = "80_red_overlay", force = game.forces.neutral, position = entity.position })
    local overlay = { player_idx = player_idx, harpa = entity, entity_list = {}, radius = 0, ticks_remaining = 15 * 30 + 12 * 60 }
    table.insert(overlay.entity_list, overlay_entity)
    table.insert(global.harpa_overlays, overlay)
end

function Harpa.update_overlays()
    if not global.harpa_overlays then
        return
    end
    for i = #global.harpa_overlays, 1, -1 do
        local overlay = global.harpa_overlays[i]
        if overlay.radius < 30 and overlay.harpa.valid and overlay.ticks_remaining % 15 == 0 then
            overlay.radius = overlay.radius + 1
            if (overlay.radius % 5 == 0) then
                local surface = overlay.harpa.surface
                local opacity = 80 - overlay.radius * 2
                local position = overlay.harpa.position
                for dx = -(overlay.radius), overlay.radius do
                    Harpa.create_overlay_entity(surface, opacity, {position.x + dx, position.y + overlay.radius}, overlay.entity_list)
                    Harpa.create_overlay_entity(surface, opacity, {position.x + dx, position.y - overlay.radius}, overlay.entity_list)
                end
                for dy = -(overlay.radius - 1), overlay.radius - 1 do
                    Harpa.create_overlay_entity(surface, opacity, {position.x + overlay.radius, position.y + dy}, overlay.entity_list)
                    Harpa.create_overlay_entity(surface, opacity, {position.x - overlay.radius, position.y - dy}, overlay.entity_list)
                end
            end
        end
        overlay.ticks_remaining = overlay.ticks_remaining - 1
        if overlay.ticks_remaining <= 0 or not overlay.harpa.valid then
            table.remove(global.harpa_overlays, i)
            for _, entity in ipairs(overlay.entity_list) do
                if entity.valid then
                    entity.destroy()
                end
            end
        end
    end
end

function Harpa.create_overlay_entity(surface, opacity, position, list)
    local overlay_entity = surface.create_entity({name = opacity .. "_red_overlay", force = game.forces.neutral, position = position})
    overlay_entity.minable = false
    overlay_entity.destructible = false
    overlay_entity.operable = false
    table.insert(list, overlay_entity)
end

function Harpa.tick(logger)
    if global.harpa_list then
        Harpa.update_overlays()
        
        for i = #global.harpa_list, 1, -1 do
            local harpa = global.harpa_list[i]
            if not harpa.valid then
                table.remove(global.harpa_list, i)
            else
                Harpa.tick_emitter(harpa, logger)
            end
        end
    end
end

function Harpa.tick_emitter(entity, logger)
    -- using x and y and tick for modulus assures emitters next to each other will scan separate rows
    local row = ((math.floor(entity.position.y) + math.floor(entity.position.x) + game.tick) % 60) - 30
    local pos = entity.position
    local area = {left_top = {pos.x - 30, pos.y - row}, right_bottom = {pos.x + 30, pos.y - row + 1}}
    -- logger:log("HARPA at (" .. pos.x .. ", " .. pos.y ..") emitting from {(" .. area.left_top[1] .. ", " .. area.left_top[2] .. "), (" .. area.right_bottom[1] .. ", " .. area.right_bottom[2] .. ")}")
    local biters = entity.surface.find_entities_filtered({area = area, type = "unit", force = "enemy"})
    -- logger:log("HARPA found " .. #biters .. " in emitting area")

    local emitter_area = {left_top = {pos.x - 50, pos.y - 50}, right_bottom = {pos.x + 50, pos.y + 50}}
    for _, biter in ipairs(biters) do
        local roll = math.random(0, 100)
        -- random chance to 1-shot kill a biter (as long as it is not a behemoth)
        if (roll >= 99) and biter.prototype.max_health < 2500 then
            biter.damage(biter.prototype.max_health, "player")
        else
            distance = math.sqrt((biter.position.x - entity.position.x) * (biter.position.x - entity.position.x) + (biter.position.y - entity.position.y) * (biter.position.y - entity.position.y))
            biter.damage(math.min(100, biter.prototype.max_health / (1 + distance)), "player")
        end

        -- check if biter is valid (damage may have killed it)
        if biter.valid and not Harpa.ignore_biter(biter) then
            local command = {}
            local ignore_time = 60 * 5
            
            -- emitter only works on non-behemoth biters
            if biter.prototype.max_health < 2500 then
                local destination = Harpa.nearest_corner(biter.position, emitter_area, math.random(1, 10), math.random(1, 10))
                destination = biter.surface.find_non_colliding_position(biter.name, destination, 20, 0.3)
                command = {type = defines.command.compound, structure_type = defines.compoundcommandtype.logical_and, commands = {
                    {type = defines.command.go_to_location, distraction = defines.distraction.by_damage, destination = destination},
                    {type = defines.command.wander}
                }}
            else
                -- emitter angers behemoth biters into attacking immediately
                command = {type = defines.command.attack, target = entity, distraction = distraction.none}
                ignore_time = 60 * 60
            end
            -- logger:log("Biter command: " .. serpent.block(command))
            if not pcall(biter.set_command, command) then
                logger:log("Error executing biter command command: " .. serpent.block(command))
            end
            table.insert(global.biter_ignore_list, {biter = biter, until_tick = game.tick + ignore_time})
        end
    end
    
    local spawners = entity.surface.find_entities_filtered({area = area, type = "unit-spawner", force = "enemy"})
    for _, spawner in ipairs(spawners) do
        spawner.damage(spawner.prototype.max_health / 250, "player")
    end
    local worms = entity.surface.find_entities_filtered({area = area, type = "turret", force = "enemy"})
    for _, worm in ipairs(worms) do
        worm.damage(worm.prototype.max_health / 100, "player")
    end
end

function Harpa.ignore_biter(entity)
    for i = #global.biter_ignore_list, 1, -1 do
        local biter_data = global.biter_ignore_list[i]
        if not biter_data.biter.valid or game.tick > biter_data.until_tick then
            table.remove(global.biter_ignore_list, i)
        elseif biter_data.biter == entity then
            return true
        end
    end
    return false
end

function Harpa.nearest_corner(pos, area, rand_x, rand_y)
    local dist_left_top = (pos.x - area.left_top[1]) * (pos.x - area.left_top[1]) + (pos.y - area.left_top[2]) * (pos.y - area.left_top[2])
    local dist_right_bottom = (pos.x - area.right_bottom[1]) * (pos.x - area.right_bottom[1]) + (pos.y - area.right_bottom[2]) * (pos.y - area.right_bottom[2])
    if (dist_left_top < dist_right_bottom) then
        local dist_right_top = (pos.x - area.right_bottom[1]) * (pos.x - area.right_bottom[1]) + (pos.y - area.left_top[2]) * (pos.y - area.left_top[2])
        if (dist_left_top < dist_right_top) then
            return {area.left_top[1] - rand_x, area.left_top[2] - rand_y}
        else
            return {area.right_bottom[1] + rand_x, area.left_top[2] - rand_y}
        end
    else
        local dist_left_bottom = (pos.x - area.left_top[1]) * (pos.x - area.left_top[1]) + (pos.y - area.right_bottom[2]) * (pos.y - area.right_bottom[2])
        if (dist_right_bottom < dist_left_bottom) then
            return {area.right_bottom[1] + rand_x, area.right_bottom[2] + rand_y}
        else
            return {area.left_top[1] - rand_x, area.right_bottom[2] + rand_y}
        end
    end
end

return Harpa
