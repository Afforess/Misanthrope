require 'libs/developer_mode'

remote.add_interface("misanthrope", {
    developer_mode = function()
        for _, player in pairs(game.players) do
            if player.valid and player.connected then
                DeveloperMode.setup(player)
            end
        end
    end
})
