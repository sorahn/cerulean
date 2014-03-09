fs        = require 'fs'
ini       = require 'ini'
binary    = require 'binary'
{resolve} = require 'path'

# Return the hex value of a string
String::asDec = -> parseInt @, 16

# Parse ini style numbers in strings.
#   hex = '$123ABC'
#   dec = '123456'
String::stupidHex = ->
  if "#{@.charAt 0}" is '$' then do "#{@.slice 1}".asDec else +@



class Cerulean
  constructor: () ->
    @main = @readIni resolve 'ini/Main.ini'
    @maps = @readIni resolve 'ini/Maps.ini'
    @tiles = @readIni resolve 'ini/Tilesets.ini'
    fs.open 'PM_CRYSTAL.GBC', 'r', (s, @fd) =>
      do @readMapHeaders

  get: -> @[arguments[0]]

  getMap: (name) ->
    map = @parseMapData @maps[name]

  getTile: (num) ->
    tile = @parseTileData @tiles[num]

  readIni: (file) ->
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

  # 0x94000 is where the Pokemon G/S/C map data starts
  # There are 26 Map groups.
  readMapHeaders: ->
    mapGroups = []

    size = 52
    buffer = new Buffer size
    fs.read @fd, buffer, 0, size, do "94000".asDec, =>
      for i in [1..size] by 2
        mapGroups.push "9#{(buffer.readUInt16LE i - 1).toString(16)}"

      @readMapGroups mapGroups

  # Each map is 9 bytes long
  readMapGroups: (mapGroups) ->
    for offset, i in mapGroups
      maps = []
      size = 9
      buffer = new Buffer size
      fs.read @fd, buffer, 0, size, do offset.asDec, =>
        console.log buffer.toString 'hex'
        mapHeader = {}
        tmp =
          binary
            .parse(buffer)
            .word8('bank')
            .word8('tileset')
            .word8('permission')
            .word16le('secondMapHeader')
            .word8('location')
            .word8('music')
            .word8('time')
            .word8('fishing')
            .vars

        console.log mapHeader

module.exports = -> new Cerulean
