require 'libs/pathfinder'
remote.add_interface("misanthrope", {
    set_expansion_phase = function(index, target)
        global.expansion_target_index = target
        global.expansion_phase_request = { index = index }
    end,
    
    show_path = function(player_idx)
        local pos = game.players[player_idx].position
        if not game.players[player_idx].selected then
            game.players[player_idx].print("No Selection")
            return
        end
        local path = pathfinder.a_star(game.players[player_idx].surface, pos, game.players[player_idx].selected.position)
        game.players[player_idx].print(serpent.line(path))

    end
})
