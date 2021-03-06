harp       = require 'harp'
require 'coffee-script/register'
###
 Harp / Terraform are using the wrong coffescript versions, I'm re-register-ing
 coffee-script here to use the right parser for included files.
###

_          = require 'lodash'
fs         = require 'fs'
util       = require 'util'
async      = require 'async'
express    = require 'express'
app        = express()
cerulean   = do require './lib/cerulean'

main_array = []
maps_ini   = cerulean.get 'maps'
tiles_ini  = cerulean.get 'tiles'
main_ini   = cerulean.get 'main'

for title, maplist of main_ini
  area =
    title: title
    id: "#{title.replace /[\. ]/g, '_'}".toLowerCase().replace /__/, '_'
    maps: []
  for key, value of maplist
    cleanValue = value.replace /\\/g, ''
    map =
      title: cleanValue
      x: maps_ini[cleanValue]['X Size']
      y: maps_ini[cleanValue]['Y Size']
    area.maps.push map
  main_array.push area

# Console Log with util.inspect built in.
clog = (obj) -> console.log util.inspect obj, {depth: 5, colors: true}

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
  tile = cerulean.getTile num
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

app.get '/', (req, res) -> res.render 'index', {maplist, main_array}

app.get '/tileset/:num', ({params: {num}}, res) ->
  get_tileset num, (err, [template, data]) -> res.render template, data

app.get '/map/:name', (req, res) ->
  {name} = req.params
  map = cerulean.getMap name
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
