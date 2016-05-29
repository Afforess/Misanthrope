require 'stdlib/event/event'
require 'stdlib/area/chunk'
require 'stdlib/area/position'
require 'stdlib/log/logger'
require 'libs/circular_buffer'

local logger = Logger.new("Misanthrope", "player_scents", DEBUG_MODE)
local Log = function(str, ...) logger.log(string.format(str, ...)) end

PLAYER_SCENT = 10000

Event.register(defines.events.on_player_created, function(event)
    global.players = game.players
end)

Event.register(defines.events.on_tick, function(event)
    if global.toggle_scents then return end
    if not global.players then global.players = game.players end

    for index, player in pairs(global.players) do
        if player.valid and player.connected and (event.tick + index) % 120 == 0 then
            local character = player.character
            if character and character.valid then
                local position = character.position
                local surface = character.surface
                local chunk_pos = Chunk.from_position(position)
                local data, idx = Chunk.get_data(surface, chunk_pos, {})
                if not data.player_scent then
                    data.player_scent = PLAYER_SCENT
                else
                    data.player_scent = data.player_scent + PLAYER_SCENT
                end

                -- Queue up spreading the scent
                if not global.player_scent_spread then global.player_scent_spread = circular_buffer.new() end

                circular_buffer.append(global.player_scent_spread, {surface, chunk_pos, data, {idx = true}})
            end
        end
    end
end)

Event.register(defines.events.on_tick, function(event)
    local player_scents = global.player_scent_spread
    for i = 1, 5 do
        if not player_scents or player_scents.count == 0 then return end

        local surface, chunk_pos, data, visited_chunks = unpack(circular_buffer.pop(player_scents))

        local spread = 0.16 * data.player_scent
        data.player_scent = math.max(0, math.floor(data.player_scent * 0.84) - 100)
        if spread > 10 then
            for idx, offset in pairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
                local chunk = Position.add(chunk_pos, offset)
                local chunk_data, chunk_idx = Chunk.get_data(surface, chunk, {})
                local old_amt = 0
                if not chunk_data.player_scent then
                    chunk_data.player_scent = math.floor(spread * 0.25)
                else
                    old_amt = chunk_data.player_scent
                    chunk_data.player_scent = math.floor(chunk_data.player_scent + (spread * 0.25))
                end
                if chunk_data.base then
                    BiterBase.on_player_scent_changed(chunk_data.base, old_amt, chunk_data.player_scent)
                end
                if chunk_data.player_scent > 30 and not visited_chunks[chunk_idx] then
                    visited_chunks[chunk_idx] = true
                    circular_buffer.append(player_scents, {surface, chunk, chunk_data, visited_chunks})
                end
            end
        end
    end
end)
