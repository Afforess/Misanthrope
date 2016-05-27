require 'stdlib/event/event'
require 'stdlib/log/logger'
require 'stdlib/entity/entity'
require 'stdlib/surface'
require 'libs/biter/base'

World = {}
World.version = 40
World.Logger = Logger.new("Misanthrope", "world", DEBUG_MODE)

function World.setup()
    local mod_version = global.mod_version
    if not global.mod_version then
        -- goodbye fair world
        local old_global = global
        global = {}
        global.mod_version = 40
        mod_version = 0

        Harpa.migrate(old_global)
    end
    if mod_version ~= global.mod_version then
        World.migrate(mod_version, World.version)
        global.mod_version = World.version
    end

    global.players = game.players
end

function World.migrate(old_version, new_version)
    World.Logger.log(string.format("Migrating world data from {%s} to {%s}...", old_version, new_version))
    if old_version < 40 then
        game.forces.enemy.kill_all_units()
        global.bases = {}
        for _, spawner in pairs(Surface.find_all_entities({ type = 'unit-spawner', surface = 'nauvis' })) do
            -- may already be dead if it was discovered and killed
            if spawner.valid then
                local data = Entity.get_data(spawner)
                if not data or not data.base then
                    BiterBase.discover(spawner)
                end
            end
        end
    end
end

function World.create_entity(surface, entity_data, owner)
    local entity = surface.create_entity(entity_data)

    if not global.entities then global.entities = circular_buffer.new() end
    if not global.entities_pending_deletion then global.entities = circular_buffer.new() end

    circular_buffer.append(global.entities, { entity = entity, owner = owner })

    return entity
end

Event.register(defines.events.on_tick, function(event)
    local tick = event.tick
    if tick % 600 == 0 then
        local iter = circular_buffer.iterator(global.entities)
        while(iter.has_next()) do
            local node = iter.next_node()
            if node then
                local entity_data = node.value
                if not entity_data.entity.valid then
                    circular_buffer.remove(global.entities, node)
                elseif not entity_data.owner.valid then
                    entity_data.reap_after = tick + 3600 * 5
                    circular_buffer.append(global.entities_pending_deletion, entity_data)
                    circular_buffer.remove(global.entities, node)
                end
            end
        end
    end
    if tick % 3600 == 0 then
        local iter = circular_buffer.iterator(global.entities_pending_deletion)
        while(iter.has_next()) do
            local node = iter.next_node()
            if node then
                local entity_data = node.value
                if not entity_data.entity.valid then
                    circular_buffer.remove(global.entities_pending_deletion, node)
                elseif entity_data.reap_after < tick then
                    entity_data.entity.destroy()
                    circular_buffer.remove(global.entities_pending_deletion, node)
                end
            end
        end
    end
end)

Event.register(Event.core_events.configuration_changed, function(event)
    World.Logger.log("Setting up world...")
    World.Logger.log("Mod data: " .. serpent.line(event.data, {comment = false}))
    World.setup()
    Event.remove(defines.events.on_tick, event._handler)
    World.Logger.log("World setup complete.")
end)
