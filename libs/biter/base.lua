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

-- Biter Base Meta-Methods
local Base = {}

function Base.get_entities(self)
    if self.entities then
        return table.filter(self.entities, Game.VALID_FILTER)
    end
    return {}
end

function Base.get_prev_entities(self)
    local plan_data = self.plan.data
    if plan_data.prev_entities then
        return table.filter(plan_data.prev_entities, Game.VALID_FILTER)
    end
    return {}
end

function Base.all_hives(self)
    local hives = {}
    table.insert(hives, self.queen)
    for _, hive in pairs(self.hives) do
        table.insert(hives, hive)
    end
    return hives
end

-- Biter Base metatable
local BaseMt = {}
BaseMt.__index = function(tbl, k)
    local raw = rawget(tbl, k)
    if raw then
        return raw
    else
        if Base[k] then
            return Base[k]
        end
    end
    return nil
end

--- Creates a biter base from spawner entity
function BiterBase.discover(entity)
    local pos = entity.position
    local surface = entity.surface

    -- initialize biter base data structure
    local base = { queen = entity, hives = {}, worms = {}, currency = 0, name = RandomName.get_random_name(14), next_tick = game.tick + math.random(300, 1000), valid = true}
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
    spawners = surface.find_entities_filtered({ area = Position.expand_to_area(pos, 32), type = 'unit-spawner', force = entity.force})
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
    if base.queen.valid then
        local pos = base.queen.position
        return string.format("{BiterBase: (name: %s, pos: (%d, %d), size: %d)}", base.name, pos.x, pos.y, (1 + #base.hives))
    else
        return string.format("{BiterBase: (name: %s, pos: (?, ?), size: %d)}", base.name, (#base.hives))
    end
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

Event.register(defines.events.on_tick, function(event)
    if not global.players then World.resync_players() end
    if not (event.tick % Time.SECOND == 0) then return end

    for _, character in pairs(World.all_characters()) do
        local chunk_pos = Chunk.from_position(character.position)
        local alert_area = Position.expand_to_area(chunk_pos, 3)
        for chunk_x, chunk_y in Area.iterate(alert_area) do
            local chunk_data = Chunk.get_data(character.surface, {x = chunk_x, y = chunk_y})
            if chunk_data and chunk_data.base then
                local base = chunk_data.base
                if base.plan.name ~= 'alert' and base.plan.name ~= 'attacked_recently' then
                    BiterBase.set_active_plan(base, 'alert', { alerted_at = game.tick })
                end
            end
        end
    end
end)

function BiterBase.tick(base)
    if not base.plan or base.plan.name == 'idle' then
        BiterBase.create_plan(base)
    else
        local plan_class = BiterBase.plans[base.plan.name].class
        if plan_class.is_expired and plan_class.is_expired(base, base.plan.data) then
            BiterBase.set_active_plan(base, 'idle')
        elseif not plan_class.tick(base, base.plan.data) then
            BiterBase.set_active_plan(base, 'idle')
        end
    end
end

function BiterBase.is_in_active_chunk(base)
    local surface = base.queen.surface
    local pos = base.queen.position
    for _, character in pairs(World.all_characters(surface)) do
        if Position.distance_squared(pos, character.position) < 25600 then
            return true
        end
    end
    return surface.get_pollution(pos) > 500
end

BiterBase.plans = {
    idle = { passive = true, cost = 1, update_frequency = 60 * 60 },
    identify_targets = { passive = true, cost = 1000, update_frequency = 300, class = require 'libs/biter/ai/identify_targets' },
    attack_area = { passive = false, cost = 1000, update_frequency = 300, class = require 'libs/biter/ai/attack_area'},
    attacked_recently = { passive = false, cost = 100, update_frequency = 120, class = require 'libs/biter/ai/attacked_recently' },
    alert = { passive = false, cost = 100, update_frequency = 180, class = require 'libs/biter/ai/alert' },
    move_base = { passive = false, cost = 500, update_frequency = 300, class = require 'libs/biter/ai/move_base' }
}

function BiterBase.create_plan(base)
    if not base.target and base.currency > BiterBase.plans.identify_targets.cost then
        Log("%s has no active targets, and chooses AI plan to identify targets", BiterBase.tostring(base))
        BiterBase.set_active_plan(base, 'identify_targets')
        return true
    end

    if base.target and base.target.type == 'player_value' then
        if BiterBase.is_in_active_chunk(base) then
            if base.currency > BiterBase.plans.attack_area.cost then
                BiterBase.set_active_plan(base, 'attack_area')
                return true
            end
        else
            if base.currency > BiterBase.plans.move_base.cost then
                BiterBase.set_active_plan(base, 'move_base')
                return true
            end
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

    if plan_data.class and plan_data.class.initialize then
        plan_data.class.initialize(base, data)
    end
end

function BiterBase.create_entity(base, surface, entity_data)
    local entity = surface.create_entity(entity_data)

    if not base.entities then base.entities = {} end
    table.insert(base.entities, entity)

    return entity
end

function BiterBase.create_unit_group(base, data)
    if not global.unit_groups then global.unit_groups = {} end
    local unit_group = base.queen.surface.create_unit_group(data)
    table.insert(global.unit_groups, {unit_group, unit_group.state, game.tick, base})
    return unit_group
end

Event.register(defines.events.on_tick, function(event)
    if not global.unit_groups then return end

    local groups = global.unit_groups
    for i = #groups, 1, -1 do
        local unit_group, prev_state, initial_tick, base = unpack(groups[i])
        if unit_group.valid then
            local current_state = unit_group.state
            if current_state ~= prev_state then
                game.raise_event(UNIT_GROUP_EVENT_ID, {unit_group = unit_group, current_state = current_state, prev_state = prev_state, initial_tick = initial_tick, base = base})
                groups[i][2] = current_state
            end
        else
            game.raise_event(UNIT_GROUP_EVENT_ID, {prev_state = prev_state, initial_tick = initial_tick, base = base})
            table.remove(groups, i)
        end
    end
end)


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
    if global.bases and tick % 60 == 0 then
        for i = #global.bases, 1, -1 do
            local base = global.bases[i]
            if not base.queen.valid then
                BiterBase.on_queen_death(base)
            else
                base.currency = base.currency + 1 + #base.hives
                if base.next_tick < tick then
                    if not getmetatable(base) then
                        setmetatable(base, BaseMt)
                    end
                    BiterBase.tick(base)
                end
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
