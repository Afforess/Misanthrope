require 'stdlib/string'

Biters = {}

function Biters.spawn_biter(base, surface, spawner)
    if spawner and spawner.valid then
        for _, unit_name in pairs(Biters.valid_units(spawner)) do
            local odds = 100 * Biters.unit_odds(unit_name)
            if odds > 0 and odds > math.random(100) then
                local spawn_pos = surface.find_non_colliding_position(unit_name, spawner.position, 6, 0.5)
                if spawn_pos then
                    return BiterBase.create_entity(base, surface, {name = unit_name, position = spawn_pos, force = spawner.force})
                end
            end
        end
    end
    return nil
end

function Biters.unit_odds(name)
    local evo_factor = game.evolution_factor
    if name:contains('behemoth') and evo_factor > 0.7 then
        return (evo_factor - 0.7) * 2
    end
    if name:contains('big') and evo_factor > 0.4 then
        return (evo_factor - 0.4) * 1.3
    end
    if name:contains('medium') and evo_factor > 0.25 then
        return math.min(0.5, evo_factor - 0.25)
    end
    if name == 'small-spitter' and evo_factor > 0.15 then
        return 0.75
    end
    if name == 'small-biter' then
        return 1
    end
    return 0
end

function Biters.valid_units(spawner)
    if spawner.name == 'spitter-spawner' then
        return {'behemoth-spitter', 'big-spitter', 'medium-spitter', 'small-spitter', 'small-biter'}
    end
    return {'behemoth-biter', 'big-biter', 'medium-biter', 'small-biter'}
end
