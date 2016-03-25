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

function pathfinder.a_star(surface, start_pos, goal_pos)
    start_pos = {x = math.floor(start_pos.x), y = math.floor(start_pos.y)}
    goal_pos = {x = math.floor(goal_pos.x), y = math.floor(goal_pos.y)}

    local surface_name = surface.name
    local closed_set = {}
    local open_set = { start_pos }
    local came_from = {}

    local g_score = {}
    local f_score = {}
    g_score[pathfinder.node_key(surface_name, start_pos)] = 0
    f_score[pathfinder.node_key(surface_name, start_pos)] = pathfinder.heuristic_cost_estimate(start_pos, goal_pos)

    local iterations = 0
    while #open_set > 0 do
        if iterations > 10000 then
            return nil
        end
        iterations = iterations + 1

        local current = pathfinder.lowest_f_score(surface_name, open_set, f_score)
        if current.x == goal_pos.x and current.y == goal_pos.y then
            local path = pathfinder.unwind_path(surface_name, {}, came_from, goal_pos)
            table.insert(path, goal_pos)
            return path
        end

        pathfinder.remove_node(open_set, current)
        table.insert(closed_set, current)

        local neighbors = pathfinder.neighbor_nodes(surface, current)
        for _, neighbor in ipairs(neighbors) do
            if pathfinder.not_in(closed_set, neighbor) then
                local tentative_g_score = g_score[pathfinder.node_key(surface_name, current)] + pathfinder.heuristic_cost_estimate(current, neighbor)

                local neighbor_key = pathfinder.node_key(surface_name, neighbor)
                if pathfinder.not_in(open_set, neighbor) or tentative_g_score < g_score[neighbor_key] then
                    came_from[neighbor_key] = current
					g_score[neighbor_key] = tentative_g_score
					f_score[neighbor_key] = g_score[neighbor_key] + pathfinder.heuristic_cost_estimate(neighbor, goal_pos)
					if pathfinder.not_in(open_set, neighbor) then
						table.insert(open_set, neighbor)
					end
                end
            end
        end
    end

    return nil
end

function pathfinder.node_key(surface_name, pos)
    return string.format("%s@{%s,%s}", surface_name, pos.x, pos.y)
end

function pathfinder.heuristic_cost_estimate(nodeA, nodeB)
    local axbx = nodeA.x - nodeB.x
    local ayby = nodeA.y - nodeB.y
    return math.sqrt(axbx * axbx + ayby * ayby)
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

function pathfinder.unwind_path(surface_name, flat_path, map, current_node)
    local map_value = map[pathfinder.node_key(surface_name, current_node)]
	if map_value then
		table.insert(flat_path, 1, map_value)
		return pathfinder.unwind_path(surface_name, flat_path, map, map_value)
	else
		return flat_path
	end
end

function pathfinder.lowest_f_score(surface_name, set, f_score)
	local lowest, best_node = nil, nil
	for _, node in ipairs(set) do
		local score = f_score[pathfinder.node_key(surface_name, node)]
		if lowest == nil or score < lowest then
			lowest, best_node = score, node
		end
	end
	return best_node
end
