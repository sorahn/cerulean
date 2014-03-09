fs        = require 'fs'
ini       = require 'ini'
binary    = require 'binary'
{resolve} = require 'path'

# Return the hex value of a string
String::getHex = -> parseInt @, 16

# Parse ini style numbers in strings.
#   hex = '$123ABC'
#   dec = '123456'
String::stupidHex = ->
  if "#{@.charAt 0}" is '$' then do "#{@.slice 1}".getHex else +@

class Cerulean
  constructor: () ->
    @main = @readIni resolve 'ini/Main.ini'
    @maps = @readIni resolve 'ini/Maps.ini'
    @tiles = @readIni resolve 'ini/Tilesets.ini'

  get: -> @[arguments[0]]

  getMap: (name) ->
    map = @parseMapData @maps[name]

  getTile: (num) ->
    tile = @parseTileData @tiles[num]

  readIni: (file) ->
    console.info "parse ini file #{file}"
    data = ini.parse fs.readFileSync file, 'utf-8'

  # Maps.ini
  # [Goldenrod Gym]
  # Start Offset = $AFBC7
  # X Size       = 10
  # Y Size       = 9
  # Tileset      = 20
  parseMapData: (raw) ->
    offset: raw['Start Offset'].stupidHex()
    width: +raw['X Size']
    height: +raw['Y Size']
    tileset: +raw['Tileset']
    title: raw.title
    size: raw['X Size'] * raw['Y Size']
    raw: raw

  # Tilesets.ini
  # [1]
  # Start offset=$19c1e
  # Tiles=crys1.dib
  # Blocks=127
  parseTileData: (raw) ->
    offset: raw['Start offset'].stupidHex()
    tiles: raw['Tiles']
    blocks: raw['Blocks'].stupidHex()
    background: raw['Tiles'].match(/\d+/)[0]
    raw: raw

module.exports = -> new Cerulean
