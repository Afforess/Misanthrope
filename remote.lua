remote.add_interface("misanthrope", {
    set_expansion_phase = function(index, target)
        global.expansion_target_index = target
        global.expansion_phase_request = { index = index }
    end,
    
    print_region_stats = function(player_idx)
        local pos = game.players[player_idx].position
        local x = bit32.arshift(math.floor(pos.x), 7)
        if (pos.x < 0) then
            x = x - 4294967296
        end
        local y = bit32.arshift(math.floor(pos.y), 7)
        if (pos.y < 0) then
            y = y - 4294967296
        end
        
        local index = bit32.bor(bit32.lshift(x, 16), bit32.band(y, 0xFFFF))
        local any_targets = global.region_has_any_targets[index] or global.region_has_any_targets[index] == nil
        game.players[player_idx].print("Region (" .. x .. ", " .. y .. ") any_targets: " .. serpent.line(any_targets))
    end
})
