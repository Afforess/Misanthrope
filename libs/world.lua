require 'stdlib/event/event'
require 'stdlib/log/logger'
require 'stdlib/entity/entity'
require 'stdlib/surface'
require 'libs/biter/base'

World = {}
World.version = 42
World.Logger = Logger.new("Misanthrope", "world", DEBUG_MODE)
local Log = function(str, ...) World.Logger.log(string.format(str, ...)) end

function World.setup()
    if not global.mod_version then
        -- goodbye fair world
        local old_global = global
        global = {}
        global.mod_version = World.version

        Harpa.migrate(old_global)
        World.recalculate_chunk_values()
    end
    if World.version ~= global.mod_version then
        World.migrate(global.mod_version, World.version)
        global.mod_version = World.version
    end

    World.resync_players()
end

function World.migrate(old_version, new_version)
    Log("Migrating world data from {%s} to {%s}...", old_version, new_version)
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
    if old_version < 41 then
        for i = #global.bases, 1, -1 do
            local base = global.bases[i]
            base.target = nil
        end
        if global.overmind then
            global.overmind.currency = 0
        end
    end
    if old_version < 42 then
        World.recalculate_chunk_values()
        for i = #global.bases, 1, -1 do
            local base = global.bases[i]
            base.targets = nil
            BiterBase.set_active_plan(base, 'idle')
        end
    end
end

function World.all_characters(surface)
    local characters = {}
    for idx, player in pairs(global.players) do
        if player.valid and player.connected then
            local character = player.character
            if character and character.valid and (surface == nil or character.surface == surface) then
                characters[idx] = character
            end
        end
    end
    return characters
end

function World.resync_players()
    global.players = {}
    for _, player in pairs(game.players) do
        table.insert(global.players, player)
    end
end

Event.register(defines.events.on_player_created, World.resync_players)

Event.register({Event.core_events.init, Event.core_events.configuration_changed}, function(event)
    Log("Setting up world...")
    if event.data then
        Log("Mod data: %s", serpent.line(event.data))
    end
    World.setup()
    Log("World setup complete.")
end)
