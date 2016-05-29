-- Adapted from: https://github.com/lattejed/a-star-lua/blob/master/a-star.lua

-- ======================================================================
-- Copyright (c) 2012 RapidFire Studio Limited
-- All Rights Reserved.
-- http://www.rapidfirestudio.com

-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:

-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-- ======================================================================

pathfinder = {}
pathfinder.__index = pathfinder

-- Partially search for a path on the given surface between the start_pos and goal_pos
-- If the search completes, the path object will be inside of the returned table { completed = true, path = { ... }}
-- If the search is not yet completed, the returned table will be { completed = false, ... }
-- Pathfinding can be resumed with pathfinder.resume_a_star
function pathfinder.partial_a_star(surface, start_pos, goal_pos, max_iterations, max_total_iterations)
    start_pos = {x = math.floor(start_pos.x), y = math.floor(start_pos.y)}
    goal_pos = {x = math.floor(goal_pos.x), y = math.floor(goal_pos.y)}

    local surface_name = surface.name
    local closed_set = {}
    local open_set = { start_pos }
    local came_from = {}

    local g_score = {}
    local f_score = {}
    g_score[pathfinder.node_key(start_pos)] = 0
    f_score[pathfinder.node_key(start_pos)] = pathfinder.heuristic_cost_estimate(start_pos, goal_pos)

    local pathfinding_data =
    {
        surface = surface,
        start_pos = start_pos,
        goal_pos = goal_pos,
        closed_set = closed_set,
        open_set = open_set,
        came_from = came_from,
        g_score = g_score,
        f_score = f_score,
        iterations = 0,
        max_total_iterations = max_total_iterations,
        completed = false
    }
    return pathfinder.resume_a_star(pathfinding_data, max_iterations)
end

-- Resumes an uncomplete pathfinding search, given the partially completed data and max iterations
function pathfinder.resume_a_star(pathfinding_data, max_iterations)
    for i = 1, max_iterations do
        local result = pathfinder.step_a_star(pathfinding_data)
        if pathfinding_data.completed then
            return { completed = true, path = result }
        end
    end
    return pathfinding_data
end

-- Find a complete path on the given surface between the start_pos and goal_pos
function pathfinder.a_star(surface, start_pos, goal_pos, max_total_iterations)
    start_pos = {x = math.floor(start_pos.x), y = math.floor(start_pos.y)}
    goal_pos = {x = math.floor(goal_pos.x), y = math.floor(goal_pos.y)}

    local surface_name = surface.name
    local closed_set = {}
    local open_set = { start_pos }
    local came_from = {}

    local g_score = {}
    local f_score = {}
    g_score[pathfinder.node_key(start_pos)] = 0
    f_score[pathfinder.node_key(start_pos)] = pathfinder.heuristic_cost_estimate(start_pos, goal_pos)

    local pathfinding_data =
    {
        surface = surface,
        start_pos = start_pos,
        goal_pos = goal_pos,
        closed_set = closed_set,
        open_set = open_set,
        came_from = came_from,
        g_score = g_score,
        f_score = f_score,
        iterations = 0,
        max_total_iterations = max_total_iterations,
        completed = false
    }
    while not pathfinding_data.completed do
        local result = pathfinder.step_a_star(pathfinding_data)
        if pathfinding_data.completed then
            return result
        end
    end
    return nil
end

function pathfinder.step_a_star(data)
    local surface_name = data.surface.name

    if #data.open_set > 0 then
        if data.iterations > data.max_total_iterations then
            data.completed = true
            return nil
        end
        data.iterations = data.iterations + 1

        local current = pathfinder.lowest_f_score(surface_name, data.open_set, data.f_score)
        if current.x == data.goal_pos.x and current.y == data.goal_pos.y then
            local path = pathfinder.unwind_path({}, data.came_from, data.goal_pos)
            table.insert(path, data.goal_pos)
            data.completed = true
            return path
        end

        pathfinder.remove_node(data.open_set, current)
        table.insert(data.closed_set, current)

        local neighbors = pathfinder.neighbor_nodes(data.surface, current)
        for _, neighbor in ipairs(neighbors) do
            if pathfinder.not_in(data.closed_set, neighbor) then
                local tentative_g_score = data.g_score[pathfinder.node_key(current)] + pathfinder.heuristic_cost_estimate(current, neighbor)

                local neighbor_key = pathfinder.node_key(neighbor)
                if pathfinder.not_in(data.open_set, neighbor) or tentative_g_score < data.g_score[neighbor_key] then
                    data.came_from[neighbor_key] = current
                    data.g_score[neighbor_key] = tentative_g_score
                    data.f_score[neighbor_key] = data.g_score[neighbor_key] + pathfinder.heuristic_cost_estimate(neighbor, data.goal_pos)
                    if pathfinder.not_in(data.open_set, neighbor) then
                        table.insert(data.open_set, neighbor)
                    end
                end
            end
        end
    end

    return nil
end

function pathfinder.node_key(pos)
    return string.format("%s,%s", pos.x, pos.y)
end

function pathfinder.heuristic_cost_estimate(nodeA, nodeB)
    --local axbx = nodeA.x - nodeB.x
    --local ayby = nodeA.y - nodeB.y
    --return math.sqrt(axbx * axbx + ayby * ayby)
    return math.abs(nodeB.x - nodeA.x) + math.abs(nodeB.y - nodeA.y)
end

function pathfinder.not_in(set, current_node)
    for _, node in ipairs(set) do
        if node.x == current_node.x and node.y == current_node.y then
            return false
        end
    end
    return true
end

function pathfinder.neighbor_nodes(surface, center_node)
    local neighbors = {}
    local adjacent = {{0, 1}, {0, -1}, {1, 0}, {-1, 0}}
    for _, tuple in pairs(adjacent) do
        if not string.find(surface.get_tile(center_node.x + tuple[1], center_node.y + tuple[2]).name, "water", 1, true) then
            table.insert(neighbors, {x = center_node.x + tuple[1], y = center_node.y + tuple[2]})
        end
    end
    return neighbors
end

function pathfinder.remove_node(set, to_remove)
    for i, node in ipairs(set) do
        if node.x == to_remove.x and node.y == to_remove.y then
            set[i] = set[#set]
            set[#set] = nil
            break
        end
    end
end

function pathfinder.unwind_path(flat_path, map, current_node)
    local map_value = map[pathfinder.node_key(current_node)]
    if map_value then
        table.insert(flat_path, 1, map_value)
        return pathfinder.unwind_path(flat_path, map, map_value)
    else
        return flat_path
    end
end

function pathfinder.lowest_f_score(surface_name, set, f_score)
    local lowest, best_node = nil, nil
    for _, node in ipairs(set) do
        local score = f_score[pathfinder.node_key(node)]
        if lowest == nil or score < lowest then
            lowest, best_node = score, node
        end
    end
    return best_node
end
