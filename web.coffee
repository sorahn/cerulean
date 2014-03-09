_          = require 'lodash'
fs         = require 'fs'
ini        = require 'ini'
harp       = require 'harp'
util       = require 'util'
async      = require 'async'
express    = require 'express'
app        = express()

# Parse an ini file
parse_ini  = (file) -> ini.parse fs.readFileSync file, 'utf-8'

maps_array = {}
area_array = []
maps_ini   = parse_ini 'ini/Maps.ini'
tiles_ini  = parse_ini 'ini/Tilesets.ini'
arealist   = parse_ini 'ini/Main.ini'

# Set up a better maps array
for title, map of maps_ini
  maps_array[title.replace('\\', '')] = map

for title, maplist of arealist
  if title != 'Beta Maps'
    area = {}
    area.title = title
    area.id = title.replace(/\s*/g, '')
    area.maps = []
    for key, value of maplist
      map = {}
      map.title = value.replace('\\', '')
      console.log map.title
      if maps_array[value]?
        map.x = maps_array[value]['X Size']
        map.y = maps_array[value]['Y Size']
      else
        map.x = 10
        map.y = 10
      area.maps.push map
    area_array.push area

# Console Log with util.inspect built in.
clog = (obj) -> console.log util.inspect obj, {depth: 5, colors: true}

# Maps.ini
# [Goldenrod Gym]
# Start Offset=$AFBC7
# X Size=10
# Y Size=9
# Tileset=20

# Parse the map data and add some other useful fields to the map object.
parse_map_data = (map) ->
  offset: parse_hex map['Start Offset']
  width: +map['X Size']
  height: +map['Y Size']
  tileset: +map['Tileset']
  title: map.title
  size: map['X Size'] * map['Y Size']

# Tilesets.ini
# [1]
# Start offset=$19c1e
# Tiles=crys1.dib
# Blocks=127

# Parse the tile data.
parse_tile_data = (tile) ->
  offset: stupid_hex tile['Start offset']
  tiles: tile['Tiles']
  blocks: parse_hex tile['Blocks']
  background: tile['Tiles'].match(/\d+/)[0]

# Parse ini style numbers.
#   hex = $123ABC
#   dec = 123456
parse_hex = (str) ->
  if str.indexOf('$') is -1 then parseInt str, 10
  else stupid_hex str

stupid_hex = (str) -> "#{str}".slice(1).get_hex()

# String helper to convert get it's hex value.
String::get_hex = -> parseInt @, 16

# Split an array every 'n' keys
reshape = (array, n) ->
  _.compact array.map (el, i) -> array.slice i, i + n if i % n is 0

read_buffer = ({size, offset}, callback) ->
  read = new Buffer size
  fd   = app.get 'fd'

  fs.read fd, read, 0, size, offset, (err, bytes, buffer) ->
    if err then clog err
    callback buffer

get_sprite_offset = (hex) -> 16 * hex.get_hex()

deep_map = (array, fn) -> array.map (a) -> a.map (b) -> b.map (fn)

# @TODO Combine these functions
buffer_to_array = (buffer) ->
  Array::map.call buffer, (num) -> "00#{num.toString 16}".substr(-2).split ''

buffer_to_pairs = (buffer) ->
  Array::map.call buffer, (num) -> "00#{num.toString 16}".substr(-2)

build_tileset = (buffer) ->
  arr = buffer_to_array buffer
  tileset = reshape arr, 16
  deep_map tileset, get_sprite_offset

get_tileset = (num, callback) ->
  tile = parse_tile_data tiles_ini[+num]
  {offset, blocks} = tile
  size = blocks * 16
  read_buffer {size, offset}, (buffer) ->
    tileset = build_tileset buffer
    callback null, ['tileset', {tileset, num, tile}]

build_map = (buffer, columns) ->
  arr = buffer_to_pairs buffer
  #map = reshape arr, columns

get_mapset = ({size, offset, width}, callback) ->
  read_buffer {size, offset}, (buffer) ->
    mapset = build_map buffer, width
    callback null, ['map', {mapset}]

# The map names have escaped periods because bash.
get_map = (name) -> maps_ini[name.replace '.', '\.']


app.configure ->
  app.set 'views', "#{__dirname}/views"
  app.set 'view engine', 'jade'

  app.use express.logger 'dev'
  app.use express.json()
  app.use express.urlencoded()

  app.use express.errorHandler {dumpExceptions: true, showStack: true}

  app.locals
    pretty: true
    inspect: util.inspect

  app.use app.router
  app.use express.static "#{__dirname}/bower_components"
  app.use '/public', express.static "#{__dirname}/public"
  app.use '/public', harp.mount "#{__dirname}/public"

app.get '/', (req, res) -> res.render 'index', {maplist, area_array, maps_array}

app.get '/tileset/:num', ({params: {num}}, res) ->
  get_tileset num, (err, [template, data]) -> res.render template, data

app.get '/map/:name', (req, res) ->
  {name} = req.params
  map = parse_map_data get_map name
  {offset, width, height, tileset, title} = map

  async.parallel
    mapset: (cb) -> get_mapset map, cb
    tiles: (cb) -> get_tileset tileset, cb
  ,  (err, {mapset: [map_tmplt, map_data], tiles: [tile_tmplt, tile_data]}) ->

    raster = map_data.mapset.map (str) ->
      tile_data.tileset["#{str}".get_hex() - 1]


    # res.send raster
    res.render map_tmplt, {raster, map_data, map, tile_data}

fs.open 'Pokemon Crystal.gbc', 'r', (s, fd) ->
  app.set 'fd', fd
  return console.log s.message if s
  app.listen process.env.PORT or 9000
