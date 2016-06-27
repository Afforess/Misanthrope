require 'libs/pathfinding_engine'

local DonateCurrency = {}

function DonateCurrency.tick(base, data)
    if global.overmind then
        global.overmind.currency = global.overmind.currency + 50 + (50 * #base:all_hives())
    end

    return false
end

return DonateCurrency
