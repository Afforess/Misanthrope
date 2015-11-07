remote.add_interface("misanthrope", {
    set_expansion_phase = function(index, target)
        global.expansion_target_index = target
        global.expansion_phase_request = { index = index }
    end
})
