require 'stdlib/event/event'
require 'stdlib/log/logger'
require 'stdlib/entity/entity'
require 'stdlib/area/position'
require 'stdlib/area/area'
require 'stdlib/table'
require 'stdlib/game'
require 'libs/biter/random_name'
require 'libs/biter/biter'
require 'libs/biter/overwatch'
require 'libs/biter/overmind'

BiterBase = {}
BiterBase.Logger = Logger.new("Misanthrope", "biter_base", DEBUG_MODE)
BiterBase.AILoggers = {}

local Log = function(str, ...) BiterBase.Logger.log(string.format(str, ...)) end
BiterBase.LogAI = function (str, base, ...)
    if not base then
        error("Missing base", 2)
    end
    local logger = BiterBase.AILoggers[base.name]
    if not logger then
        logger = Logger.new("Misanthrope", "ai/" .. base.name, DEBUG_MODE)
        BiterBase.AILoggers[base.name] = logger
    end
    logger.log(string.format(str, ...))
end
local LogAI = BiterBase.LogAI

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

function Base.wanted_hive_count(self)
    return math.max(0, 1 + (game.evolution_factor / 0.1) - #self:all_hives())
end

function Base.wanted_worm_count(self)
    local alert_count = 0
    if self.history['alert'] then
        alert_count = alert_count + self.history['alert']
    end

    return math.max(0, 1 + alert_count - #self.worms)
end

function Base.can_afford(self, plan)
    return self.currency >= BiterBase.plans[plan].cost
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
    local base = { queen = entity, hives = {}, worms = {}, currency = 0, name = RandomName.get_random_name(14), next_tick = game.tick + math.random(300, 1000), history = {}, valid = true}
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

    return base
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
    base.hives = table.filter(base.hives, Game.VALID_FILTER)
    if #base.hives == 0 then
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
    local closest_dist = -1
    for _, character in pairs(World.all_characters(surface)) do
        local dist_squared = Position.distance_squared(pos, character.position)
        if dist_squared < 25600 then
            return true
        end
        if closest_dist == -1 or dist_squared < closest_dist then
            closest_dist = dist_squared
        end
    end
    LogAI("Closest dist: %d", base, closest_dist)
    -- if players are > 1000 away, never active
    if closest_dist > 1000000 then
        return false
    end
    return surface.get_pollution(pos) > 5
end

BiterBase.plans = {
    idle = { passive = true, cost = 1, update_frequency = 60 * 60 },
    identify_targets = { passive = true, cost = 500, update_frequency = 120, class = require 'libs/biter/ai/identify_targets' },
    attack_area = { passive = false, cost = 3000, update_frequency = 300, class = require 'libs/biter/ai/attack_area'},
    harrassment = { passive = false, cost = 7000, update_frequency = 173, class = require 'libs/biter/ai/harrassment'},
    attacked_recently = { passive = false, cost = 240, update_frequency = 120, class = require 'libs/biter/ai/attacked_recently' },
    alert = { passive = false, cost = 120, update_frequency = 180, class = require 'libs/biter/ai/alert' },
    grow_hive = { passive = true, cost = 2000, update_frequency = 300, class = require 'libs/biter/ai/grow_hive' },
    build_worm = { passive = true, cost = 1000, update_frequency = 300, class = require 'libs/biter/ai/build_worm' },
    donate_currency = { passive = true, cost = 1000, update_frequency = 300, class = require 'libs/biter/ai/donate_currency' },
}

function BiterBase.create_plan(base)
    LogAI("", base)
    LogAI("--------------------------------------------------", base)
    LogAI("Choosing new plan, currency: %s", base, serpent.line(base.currency))
    LogAI("Current Number of Hives in Base: %d", base, #base:all_hives())
    LogAI("Current Number of Worms in Base: %d", base, #base.worms)

    if base:can_afford('identify_targets') then
        if not base.targets then
            LogAI("No active targets, chooses AI plan to identify targets", base)
            BiterBase.set_active_plan(base, 'identify_targets')
            return true
        end

        local age = game.tick - base.targets.tick
        if math.random(1000) < (age / Time.MINUTE) then
            LogAI("Recalculating targets, previous target is %s minutes old", base, serpent.line((age / Time.MINUTE)))
            BiterBase.set_active_plan(base, 'identify_targets')
            return true
        end
    end

    if math.random(100) < 5 and base:can_afford('donate_currency') then
        LogAI("Choosing to donate currency to the overmind AI", base)
        BiterBase.set_active_plan(base, 'donate_currency')
        return true
    end

    local active_chunk = BiterBase.is_in_active_chunk(base)
    if active_chunk then LogAI("Is in an active chunk: true", base) else LogAI("Is in an active chunk: false", base) end
    if not active_chunk and math.random(100) > 50 and base:can_afford('donate_currency') then
        LogAI("Choosing to donate currency to the overmind AI", base)
        BiterBase.set_active_plan(base, 'donate_currency')
        return true
    end

    if math.random(100) > 60 then
        local wanted_hives = base:wanted_hive_count()
        LogAI("Wanted new hives: %d", base, wanted_hives)
        if wanted_hives > 0 and base:can_afford('grow_hive') then
            BiterBase.set_active_plan(base, 'grow_hive')
            return true
        end

        local wanted_worms = base:wanted_worm_count()
        LogAI("Wanted new worms: %d", base, wanted_worms)
        if wanted_worms > 0 and base:can_afford('build_worm') and math.random(100) > 70 then
            BiterBase.set_active_plan(base, 'build_worm')
            return true
        end
    end

    local evo_factor = game.evolution_factor * 100

    if evo_factor > 30 and math.random(100) > 80 and base:can_afford('harrassment') and base.targets then
        if active_chunk then
            BiterBase.set_active_plan(base, 'harrassment')
            return true
        end
    end

    if math.random(100) < evo_factor and base:can_afford('attack_area') and base.targets then
        if active_chunk then
            BiterBase.set_active_plan(base, 'attack_area')
            return true
        end
    end

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
                BiterBase.destroy_entity(entity)
            end)
            base.entities = nil
        else
            data.prev_entities = table.filter(base.entities, Game.VALID_FILTER)
            base.entities = data.prev_entities
        end
    end
    if old_plan then
        LogAI("Changing AI plan from {%s} to {%s}", base, base.plan.name, plan_name)
    else
        LogAI("Switching AI plan to {%s}", base, plan_name)
    end

    base.plan = { name = plan_name, data = data, valid = true}
    base.currency = base.currency - plan_data.cost
    base.next_tick = game.tick + plan_data.update_frequency
    if base.history[plan_name] then
        base.history[plan_name] = base.history[plan_name] + 1
    else
        base.history[plan_name] = 1
    end

    if plan_data.class and plan_data.class.initialize then
        plan_data.class.initialize(base, data)
    end
end

function BiterBase.create_entity(base, surface, entity_data)
    local entity = surface.create_entity(entity_data)

    if not base.entities then base.entities = {} end
    table.insert(base.entities, entity)

    local evo_cost = 0.00000025 * game.entity_prototypes[entity_data.name].max_health
    game.evolution_factor = game.evolution_factor - evo_cost

    return entity
end

function BiterBase.destroy_entity(entity)
    if not entity or not entity.valid then
        return
    end
    local evo_cost = 0.00000025 * game.entity_prototypes[entity.name].max_health
    game.evolution_factor = game.evolution_factor + evo_cost
    entity.destroy()
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
