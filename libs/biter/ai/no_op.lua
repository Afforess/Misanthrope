
local NoOp = {}

function NoOp.tick(base, data)
    return true
end

function NoOp.is_expired(base, data)
    return game.tick > data.end_tick
end

function NoOp.initialize(base, data)
    data.end_tick = game.tick + Time.MINUTE * 2
end

return NoOp
