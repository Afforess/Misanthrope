
local AbandonHive = {stages = {}}
local Log = function(str, ...) BiterBase.LogAI("[AbandonHive] " .. str, ...) end

function AbandonHive.tick(base, data)
    if global.overmind then
        global.overmind.currency = global.overmind.currency + 15000 + (10000 * #base:all_hives())
    end
    for i = #base.hives, 1, -1 do
        if base.hives[i] and base.hives[i].valid then
            base.hives[i].destroy()
        end
    end
    base.hives = {}
    for i = #base.worms, 1, -1 do
        if base.worms[i] and base.worms[i].valid then
            base.worms[i].destroy()
        end
    end
    base.worms = {}
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
