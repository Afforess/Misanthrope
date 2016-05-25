DEBUG_MODE = true

require 'defines'
require 'stdlib/log/logger'
require 'remote'
require 'libs/EvoGUI'
require 'libs/world'
require 'libs/map_settings'
require 'libs/harpa'
require 'libs/region/biter_scents'
require 'libs/region/player_scents'

LOGGER = Logger.new("Misanthrope", "main", DEBUG_MODE)
