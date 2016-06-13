require 'libs/pathfinder'

PathfindingEngine = {}

function PathfindingEngine.request_path(surface, start_pos, end_pos, max_iterations)
    if not global.pathfinding_count then global.pathfinding_count = 0 end
    if not global.pathfinding_requests then global.pathfinding_requests = {} end

    local request = pathfinder.partial_a_star(surface, start_pos, end_pos, 1, max_iterations)
    global.pathfinding_count = global.pathfinding_count + 1
    global.pathfinding_requests[global.pathfinding_count] = request

    return global.pathfinding_count
end

function PathfindingEngine.is_path_complete(request_id)
    return global.pathfinding_requests[request_id].completed
end

function PathfindingEngine.retreive_path(request_id)
    local result = global.pathfinding_requests[request_id]
    global.pathfinding_requests[request_id] = nil

    return result
end

Event.register(defines.events.on_tick, function(event)
    if global.pathfinding_requests and event.tick % 3 == 0 then
        local iterations = 0
        for i, request in pairs(global.pathfinding_requests) do
            if not request.completed then
                global.pathfinding_requests[i] = pathfinder.resume_a_star(request, 3)
                iterations = iterations + 1
                if iterations >= 5 then
                    break
                end
            end
        end
    end
end)
