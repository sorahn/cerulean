fs        = require 'fs'
ini       = require 'ini'
binary    = require 'binary'
byline    = require 'byline'
{resolve} = require 'path'

# Return the hex value of a string
String::getHex = -> parseInt @, 16

# Parse ini style numbers in strings.
#   hex = '$123ABC'
#   dec = '123456'
String::$hex = ->
  if "#{@.charAt 0}" is '$' then do "#{@.slice 1}".getHex else +@

class Cerulean
  constructor: () ->
    @mapConstants = {}
    @main         = @readIni resolve 'ini/Main.ini'
    @maps         = @readIni resolve 'ini/Maps.ini'
    @tiles        = @readIni resolve 'ini/Tilesets.ini'

    do @readMapConstants

  get: -> @[arguments[0]]

  getMap: (name) ->
    map = @parseMapData @maps[name]

  getTile: (num) ->
    tile = @parseTileData @tiles[num]

  readIni: (file) ->
    console.info "parse ini file #{file}"
    data = ini.parse fs.readFileSync file, 'utf-8'

  readMapConstants: () ->
    file          = resolve 'bower_components/pokecrystal/constants/map_constants.asm'
    stream        = byline.createStream fs.createReadStream file, {encoding: 'utf8'}

    stream.on 'data', (line) =>
      [key, value] = line.split ' EQU '

      if 0 is key.indexOf 'GROUP_'
        @mapConstants[key.replace /GROUP_/, ''] = {group: value}

      if 0 is key.indexOf 'MAP_'
        @mapConstants[key.replace /MAP_/, '']?.id = value

      if -1 isnt key.indexOf '_HEIGHT'
        @mapConstants[key.replace /_HEIGHT/, '']?.height = +value

      if -1 isnt key.indexOf '_WIDTH'
        @mapConstants[key.replace /_WIDTH/, '']?.width = +value

    stream.end = =>
      do @readMapHeaders

  readMapHeaders: ->

  # Maps.ini
  # [Goldenrod Gym]
  # Start Offset = $AFBC7
  # X Size       = 10
  # Y Size       = 9
  # Tileset      = 20
  parseMapData: (raw) ->
    offset: do raw['Start Offset'].$hex
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
    offset: do raw['Start offset'].$hex
    tiles: raw['Tiles']
    blocks: do raw['Blocks'].$hex
    background: (raw['Tiles'].match /\d+/)[0]
    raw: raw

module.exports = -> new Cerulean
