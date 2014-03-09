_ = require 'lodash'
fs = require 'fs'
ini = require 'ini'
util = require 'util'
async = require 'async'
{resolve} = require 'path'

class Cerulean
  constructor: (@app) ->
    @main = read_ini resolve 'ini/Main.ini'
    @maps = read_ini resolve 'ini/Maps.ini'
    @tiles = read_ini resolve 'ini/Tilesets.ini'

  get: -> @[arguments[0]]

  read_ini = (file) ->
    console.info "parse ini file #{file}"
    ini.parse fs.readFileSync file, 'utf-8'

module.exports = (app) -> new Cerulean app
