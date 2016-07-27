
local AbandonHive = {stages = {}}
local Log = function(str, ...) BiterBase.LogAI("[AbandonHive] " .. str, ...) end

function AbandonHive.tick(base, data)
    if global.overmind then
        global.overmind.currency = global.overmind.currency + 15000 + (10000 * #base:all_hives())
    end
    table.each(base.hives, function(hive)
        hive.destroy()
    end)
    base.hives_pos = {}
    table.each(base.worms, function(worm)
        worm.destroy()
    end)
    base.worms_pos = {}
    if base.queen.valid then
        base.queen.destroy()
    end
    if game.evolution_factor < 0.8 then
        game.evolution_factor = math.min(1, game.evolution_factor + 0.0001)
    end
    base.valid = false

    return true
end

return AbandonHive
