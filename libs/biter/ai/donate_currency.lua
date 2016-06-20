require 'libs/pathfinding_engine'

local DonateCurrency = {}

function DonateCurrency.tick(base, data)
    if global.overmind then
        global.overmind.currency = global.overmind.currency + 100
    end

    return false
end

return DonateCurrency
