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

    for _, base in pairs(global.bases) do
        BiterBase.setup(base)
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

Event.register(Event.core_events.configuration_changed, function(event)
    World.Logger.log("Setting up world...")
    World.Logger.log("Mod data: " .. serpent.line(event.data, {comment = false}))
    World.setup()
    Event.remove(defines.events.on_tick, event._handler)
    World.Logger.log("World setup complete.")
end)
