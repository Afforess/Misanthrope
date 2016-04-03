require 'libs/pathfinder'
require 'libs/pathfinder_demo'

remote.add_interface("misanthrope", {
    set_expansion_phase = function(index, target)
        global.expansion_target_index = target
        global.expansion_phase_request = { index = index }
    end,

    toggle_attack_plans = function()
        if not global.toggle_attack_plans then
            global.toggle_attack_plans = true
        else
            global.toggle_attack_plans = false
        end
    end,

    show_path = function(player_idx)
        local pos = game.players[player_idx].position
        if not game.players[player_idx].selected then
            game.players[player_idx].print("No Selection")
            return
        end
        local path = pathfinder.a_star(game.players[player_idx].surface, pos, game.players[player_idx].selected.position)
        game.players[player_idx].print(serpent.line(path))
    end,

    demo_path = function(player_idx)
        local pos = game.players[player_idx].position
        if not game.players[player_idx].selected then
            game.players[player_idx].print("No Selection")
            return
        end
        if global.pathfinding_demo then
            local demo_data = global.pathfinding_demo
            for _, entity in pairs(demo_data.entities) do
                if entity.valid then
                    entity.destroy()
                end
            end
            global.pathfinding_demo = nil
        end
        global.pathfinding_demo =
        {
            surface = game.players[player_idx].surface,
            start_pos = pos,
            goal_pos = game.players[player_idx].selected.position
        }
    end
})
