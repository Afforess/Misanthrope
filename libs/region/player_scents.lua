require 'stdlib/event/event'
require 'stdlib/area/chunk'
require 'stdlib/area/position'
require 'stdlib/log/logger'
require 'libs/circular_buffer'

player_scents = {}
player_scents.Logger = Logger.new("Misanthrope", "player_scents", DEBUG_MODE)

PLAYER_SCENT = 10000

Event.register(defines.events.on_tick, function(event)
    for index, player in pairs(game.players) do
        if player.valid and player.connected and (event.tick + index) % 300 == 0 then
            local character = player.character
            if character and character.valid then
                local position = character.position
                local surface = character.surface
                local chunk_pos = Chunk.from_position(position)
                local data = Chunk.get_data(surface, chunk_pos, {})
                if not data.player_scent then
                    data.player_scent = PLAYER_SCENT
                else
                    data.player_scent = data.player_scent + PLAYER_SCENT
                end

                -- Queue up spreading the scent
                if not global.player_scent_spread then global.player_scent_spread = circular_buffer.new() end

                for x,y in Area.spiral_iterate(Position.expand_to_area(chunk_pos, 15)) do
                    circular_buffer.append(global.player_scent_spread, {surface, { x = x, y = y}})
                end
            end
        end
    end
end)

Event.register(defines.events.on_tick, function(event)
    if not global.player_scent_spread or global.player_scent_spread.count == 0 then return end

    local surface, chunk_pos = unpack(circular_buffer.pop(global.player_scent_spread))

    local data = Chunk.get_data(surface, chunk_pos, {})
    if data.player_scent then
        local spread = 0.20 * data.player_scent
        data.player_scent = math.floor(data.player_scent * 0.70)
        if spread > 10 then
            for idx, offset in pairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
                local chunk = Position.add(chunk_pos, offset)
                local chunk_data = Chunk.get_data(surface, chunk, {})
                --local chunk_data = {}
                if not chunk_data.player_scent then
                    chunk_data.player_scent = math.floor(spread * 0.25)
                else
                    chunk_data.player_scent = math.floor(chunk_data.player_scent + (spread * 0.25))
                end
            end
        end
    end
end)
