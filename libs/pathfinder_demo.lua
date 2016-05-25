require 'libs/pathfinder'

pathfinder_demo = {}
pathfinder_demo.__index = pathfinder_demo

function pathfinder_demo.tick()
    if game.tick % 30 ~= 0 then
        return
    end
    if global.pathfinding_demo then
        local demo_data = global.pathfinding_demo
        if demo_data.ticks_remaining ~= nil then
            LOGGER.log("Counting down demo ticks: " .. demo_data.ticks_remaining)
            demo_data.ticks_remaining = demo_data.ticks_remaining - 1
            if demo_data.ticks_remaining <= 0 then
                for _, entity in pairs(demo_data.entities) do
                    if entity.valid then
                        entity.destroy()
                    end
                end
                global.pathfinding_demo = nil
            end
        elseif demo_data.started then
            global.pathfinding_demo.data = pathfinder.resume_a_star(global.pathfinding_demo.data, 10)
            local pathfinding_data = global.pathfinding_demo.data
            --LOGGER.log("Pathfinding Data: \n" .. serpent.block(pathfinding_data, {comments = false}))

            if pathfinding_data.completed then
                demo_data.ticks_remaining = 200
                if pathfinding_data.path then
                    for _, position in ipairs(pathfinding_data.path) do
                        local overlay_entity = global.pathfinding_demo.surface.create_entity({name = "rm_overlay", force = game.forces.neutral, position = position })
                        overlay_entity.minable = false
                        overlay_entity.destructible = false
                        overlay_entity.operable = false
                        table.insert(demo_data.entities, overlay_entity)
                    end
                end
            else
                for _, position in ipairs(pathfinding_data.open_set) do
                    if pathfinding_data.surface.count_entities_filtered({name = "30_red_overlay", area = {left_top = position, right_bottom = {x = position.x + 0.99, y = position.y + 0.99}} }) == 0 then
                        local overlay_entity = pathfinding_data.surface.create_entity({name = "30_red_overlay", force = game.forces.neutral, position = position })
                        overlay_entity.minable = false
                        overlay_entity.destructible = false
                        overlay_entity.operable = false
                        table.insert(demo_data.entities, overlay_entity)
                    end
                end
            end
        else
            LOGGER.log("Starting demo: " .. serpent.line(demo_data))
            demo_data.data = pathfinder.partial_a_star(demo_data.surface, demo_data.start_pos, demo_data.goal_pos, 1)
            demo_data.started = true
            demo_data.entities = {}
        end
    end
end
