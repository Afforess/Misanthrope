require 'stdlib/gui/gui'

DeveloperMode = {}

function DeveloperMode.setup(player)
    local top_gui = player.gui.top
    if not top_gui['misanthrope_debug_toggle'] then
        top_gui.add({type = 'button', name = 'misanthrope_debug_toggle', style = 'button_style', caption = {'gui.misanthrope.developer_mode'}})
    end
end

function DeveloperMode.close(player)
    local top_gui = player.gui.top
    if top_gui['misanthrope_debug_toggle'] then
        top_gui['misanthrope_debug_toggle'].destroy()
    end
end

function DeveloperMode.get_gui_setting(setting_name, default_val)
    if not global.settings then return default_val end
    if global.settings[setting_name] then
        return global.settings[setting_name]
    end
    return default_val
end

function DeveloperMode.set_gui_setting(setting_name, val)
    if not global.settings then global.settings = {} end
    global.settings[setting_name] = val
end

Gui.on_click('misanthrope_debug_toggle', function(event)
    local player = game.players[event.player_index]
    local center_gui = player.gui.center
    if not center_gui["misanthrope_frame"] then
        local frame = center_gui.add({type = 'frame', name = 'misanthrope_frame', direction = 'vertical'})
        local settings = {debug_logging = DEBUG_MODE, biter_overmind = true, harpa = true, player_scent = true}
        for setting_name, default_val in pairs(settings) do
            local item_frame = frame.add({type = 'frame', name = setting_name .. 'frame', style = 'misanthrope_wide_naked_frame_style', direction = 'horizontal'})
            item_frame.add({type = 'label', name = setting_name .. 'frame', caption = {'gui.misanthrope.' .. setting_name}})
            item_frame.add({type = 'checkbox', name = setting_name .. 'checkbox', state = DeveloperMode.get_gui_setting(setting_name, default_val)})
        end
        local biter_frame = frame.add({type = 'frame', name = 'biter_ai_frame', style = 'frame_in_right_container_style', direction = 'vertical'})
        
        frame.add({type = 'button', name = 'close_misanthrope_frame', caption = {'gui.misanthrope.close'}})
        frame.add({type = 'button', name = 'disable_developer_mode', caption = {'gui.misanthrope.disable_developer_mode'}})
    end
end)

Gui.on_click('close_misanthrope_frame', function(event)
    event.element.parent.destroy()
end)

Gui.on_click('disable_developer_mode', function(event)
    local player = game.players[event.player_index]
    DeveloperMode.close(player)
    event.element.parent.destroy()
end)

local checkbox_func = function(event)
    local element = event.element
    local state = element.state
    local setting_name = element.name:sub(0, element.name:len() - 9)
    if state then
        element.state = false
        DeveloperMode.set_gui_setting(setting_name, false)
    else
        element.state = true
        DeveloperMode.set_gui_setting(setting_name, true)
    end
    World.Logger.log("Misanthrope settings: " .. serpent.block(global.settings))
end

Gui.on_click('biter_ai_checkbox', checkbox_func)
Gui.on_click('biter_overmind_checkbox', checkbox_func)
Gui.on_click('harpa_checkbox', checkbox_func)
Gui.on_click('player_scent_checkbox', checkbox_func)
