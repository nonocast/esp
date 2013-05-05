exports = module.exports = esp = {}

web = require './web'
persist = require './persist'

store = persist.Store.instance()
router = new web.Router
server = new web.Server router

esp.Model = persist.Model

esp.run = (port) ->
  store.load ->
    console.log "store loaded"
  server.run port

esp.route = (callback) -> callback.apply router if callback?
esp.store = store
