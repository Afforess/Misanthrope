require 'stdlib/event/event'
require 'stdlib/log/logger'
require 'stdlib/entity/entity'
require 'stdlib/area/position'
require 'stdlib/area/area'
require 'stdlib/table'
require 'stdlib/game'
require 'libs/biter/random_name'
require 'libs/biter/biter'

BiterBase = {}
BiterBase.Logger = Logger.new("Misanthrope", "biter_base", DEBUG_MODE)
local Log = function(str, ...) BiterBase.Logger.log(string.format(str, ...)) end

--- Creates a biter base from spawner entity
function BiterBase.discover(entity)
    local pos = entity.position
    local surface = entity.surface

    -- initialize biter base data structure
    local base = { queen = entity, hives = {}, worms = {}, currency = 0, name = RandomName.get_random_name(14), targets = {}, next_tick = game.tick + math.random(300, 1000), valid = true}
    table.insert(global.bases, base)
    Entity.set_data(entity, {base = base})
    local chunk_data = Chunk.get_data(surface, Chunk.from_position(pos), {})
    chunk_data.base = base
    Log("Created new biter base {%s} at (%d, %d)", base.name, pos.x, pos.y)

    -- scan for nearby unclaimed hives
    local nearby_area = Position.expand_to_area(pos, 10)
    local spawners = surface.find_entities_filtered({ area = nearby_area, type = 'unit-spawner', force = entity.force})
    for _, spawner in pairs(spawners) do
        if spawner ~= entity then
            -- associate each of these entities with the base
            Entity.set_data(spawner, {base = base})
            table.insert(base.hives, spawner)
        end
    end
    Log("Discovered {%d} hives near %s", #base.hives, BiterBase.tostring(base))

    -- scan for nearby unclaimed worms
    local worms = surface.find_entities_filtered({ area = nearby_area, type = 'turret', force = entity.force})
    for _, worm in pairs(worms) do
        -- associate each of these entities with the base
        Entity.set_data(worm, {base = base})
        table.insert(base.worms, worm)
    end
    Log("Discovered {%d} worms near %s", #base.worms, BiterBase.tostring(base))

    -- destroy hives too close, but too far to be useful
    local reclaimed_evo = 0
    local spawners = surface.find_entities_filtered({ area = Position.expand_to_area(pos, 32), type = 'unit-spawner', force = entity.force})
    for _, spawner in pairs(spawners) do
        if not Area.inside(nearby_area, spawner.position) then
            spawner.destroy()
            reclaimed_evo = reclaimed_evo + 0.003
        end
    end
    Log("Destroyed {%d} hives near %s", math.floor(reclaimed_evo / 0.003), BiterBase.tostring(base))
    game.evolution_factor = math.min(1, game.evolution_factor + reclaimed_evo)
end

function BiterBase.tostring(base)
    if type(base) ~= 'table' then
        error("Invalid biter base", 2)
    end
    local pos = base.queen.position
    return string.format("{BiterBase: (name: %s, pos: (%d, %d), size: %d)}", base.name, pos.x, pos.y, (1 + #base.hives))
end

function BiterBase.on_queen_death(base)
    Log("Biter Base queen died at %s", BiterBase.tostring(base))
    local hives = #table.filter(base.hives, Game.VALID_FILTER)
    if hives == 0 then
        Log("%s has no remaining hives, and no queen. ", BiterBase.tostring(base))
        base.valid = false
        global.bases = table.filter(global.bases, Game.VALID_FILTER)
    else
        local new_queen = table.remove(base.hives, 1)
        base.queen = new_queen
        Log("%s has appointed a new queen at (%d, %d)", BiterBase.tostring(base), new_queen.position.x, new_queen.position.y)
    end
end

function BiterBase.on_player_scent_changed(base, prev_amt, new_amt)
    Log("Player scent increased from {%d} to {%d} at %s", prev_amt, new_amt, BiterBase.tostring(base))
    if (new_amt > 3 * prev_amt and new_amt > 3000) or (new_amt > 20000 and prev_amt < new_amt) then
        if base.plan.name ~= 'alert' and base.plan.name ~= 'attacked_recently' then
            BiterBase.set_active_plan(base, 'alert', { alerted_at = game.tick })
        end
    end
end

function BiterBase.tick(base)
    if not base.plan or base.plan.name == 'idle' then
        BiterBase.create_plan(base)
    else
        local plan_class = BiterBase.plans[base.plan.name].class
        if not plan_class.tick(base, base.plan.data) then
            BiterBase.set_active_plan(base, 'idle')
        end
    end
end

BiterBase.plans = {
    idle = { passive = true, cost = 1, update_frequency = 60 * 60 },
    identify_targets = { passive = true, cost = 100, update_frequency = 300, class = require 'libs/biter/ai/identify_targets' },
    attack_area = { passive = false, cost = 1000, update_frequency = 300 },
    attacked_recently = { passive = false, cost = 100, update_frequency = 120, class = require 'libs/biter/ai/attacked_recently' },
    alert = { passive = false, cost = 100, update_frequency = 180, class = require 'libs/biter/ai/alert' }
}

function BiterBase.create_plan(base)
    if #base.targets == 0 and base.currency > BiterBase.plans.identify_targets.cost then
        Log("%s has no active targets, and chooses AI plan to identify targets", BiterBase.tostring(base))
        BiterBase.set_active_plan(base, 'identify_targets')
        return true
    end
    if #base.targets > 0 then
        for _, plan in pairs(table.filter(BiterBase.plans, function(plan) return not plan.passive end)) do

        end
    end

    Log("%s has no active plans, and failed to choose any new plan. Idling.", BiterBase.tostring(base))
    BiterBase.set_active_plan(base, 'idle')
    return false
end

function BiterBase.set_active_plan(base, plan_name, extra_data)
    local plan_data = BiterBase.plans[plan_name]
    local data = {}
    if extra_data then
        data = extra_data
    end

    -- cleanup old plan
    local old_plan = base.plan
    if old_plan then old_plan.valid = false end
    if base.entities then
        if plan_data.passive then
            table.each(table.filter(base.entities, Game.VALID_FILTER), function(entity)
                entity.destroy()
            end)
            base.entities = nil
        else
            data.prev_entities = table.filter(base.entities, Game.VALID_FILTER)
            base.entities = data.prev_entities
        end
    end
    if old_plan then
        Log("Biters at %s change AI plan from {%s} to {%s}", BiterBase.tostring(base), base.plan.name, plan_name)
    else
        Log("Biters at %s change AI plan to {%s}", BiterBase.tostring(base), plan_name)
    end

    base.plan = { name = plan_name, data = data, valid = true}
    base.currency = base.currency - plan_data.cost
    base.next_tick = game.tick + plan_data.update_frequency
end

function BiterBase.create_entity(base, surface, entity_data)
    local entity = surface.create_entity(entity_data)

    if not base.entities then base.entities = {} end
    table.insert(base.entities, entity)

    return entity
end

Event.register(defines.events.on_trigger_created_entity, function(event)
    if event.entity.name == 'spawner-damaged' then
        local data = Chunk.get_data(event.entity.surface, Chunk.from_position(event.entity.position))
        Log("Trigger entity created, chunk_data: %s", serpent.block(data, {comment = false}))
        if data and data.base then
            data.base.last_attacked = event.tick
            if data.base.plan.name ~= 'attacked_recently' then
                BiterBase.set_active_plan(data.base, 'attacked_recently')
            end
        end
        event.entity.destroy()
    end
end)

Event.register(defines.events.on_tick, function(event)
    local tick = event.tick
    if tick % 60 == 0 then
        for i = 1, #global.bases do
            local base = global.bases[i]
            base.currency = base.currency + 1 + #base.hives
            if base.next_tick < tick then
                BiterBase.tick(base)
            end
        end
    end
end)

Event.register(defines.events.on_chunk_generated, function(event)
    local area = event.area
    local surface = event.surface

    -- Run one tick later to ensure compatibility with mods that are doing stuff in on_chunk_generated
    Event.register(defines.events.on_tick, function(event)
        Log("Chunk generated, checking area {%s} for spawners", serpent.line(area, {comment=false}))
        for _, spawner in pairs(surface.find_entities_filtered({area = area, type = 'unit-spawner', force = game.forces.enemy})) do
            if spawner.valid then
                local data = Entity.get_data(spawner)
                if not data or not data.base then
                    BiterBase.discover(spawner)
                end
            end
        end

        Event.remove(defines.events.on_tick, event._handler)
    end)
end)

Event.register(defines.events.on_entity_died, function(event)
    local entity = event.entity
    if entity.type == 'unit-spawner' then
        local data = Entity.set_data(entity, nil)
        if data and data.base then
            local base = data.base
            if base.queen == entity then
                BiterBase.on_queen_death(base)
            else
                for i = #base.hives, 1, -1 do
                    if base.hives[i] == entity then
                        table.remove(base.hives, i)
                    end
                end
            end
        end
    end
end)
