require 'libs/pathfinding_engine'

local SaveCurrency = {}

function SaveCurrency.tick(base, data)
    local save_amt = math.floor(base:get_currency(false) / 4)
    if save_amt > 0 then
        base.currency.amt = base.currency.amt - save_amt
        base.currency.savings = base.currency.savings + save_amt
    end

    return false
end

return SaveCurrency
