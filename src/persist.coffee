guid = require 'guid'
fs = require 'fs'
events = require 'events'
util = require 'util'
moment = require 'moment'
moment.lang 'zh-cn'

exports.Store = class Store
  _instance = null
  @instance: -> _instance = _instance or new Store

  constructor: ->
    @index = {}
    @types = {}

    @sqlite = require('sqlite3').verbose()
    @db = new @sqlite.Database('data')
    @db.exec """
      CREATE TABLE IF NOT EXISTS [document] (
        [seq] INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        [id] GUID NOT NULL,
        [createdAt] DATETIME DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
        [updatedAt] DATETIME DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
        [type] TEXT NOT NULL,
        [payload] TEXT NOT NULL);
      CREATE INDEX IF NOT EXISTS [id_index] on [document]([id]);
      """

  push: (target) ->
    return if target.id? and target.id of @index
    @onCreate target

  listen: (target) ->
    target.on 'save', (e) => @onSave target
    target.on 'delete', (e) => @onDelete target

  onCreate: (target) ->
    type = target.constructor.name

    unless target.id?.length > 0
      target.id = guid.create().value
      target.createdAt = moment()
      target.updatedAt = target.createdAt

      args = [target.id, type, @json(target)]
      @db.run 'INSERT INTO [document] ([id],[type],[payload]) VALUES (?,?,?);', args

    @index[target.id] = target
    @[type] = @[type] or {}
    @[type][target.id] = target
    @listen target
    return target

  onSave: (target) ->
    target.updatedAt = moment()
    args = [@json(target), target.updatedAt.format('YYYY-MM-DD HH:mm:ss.SSS'), target.id]
    @db.run 'UPDATE [document] SET [payload]=?, [updatedAt]=? WHERE [id]=?;', args
    return target

  onDelete: (target) ->
    @db.run 'DELETE FROM [document] WHERE [id]=?;', target.id, =>
      delete @index[target.id]
      type = target.constructor.name
      delete @[type][target.id]
      target.id = null

  load: (callback) =>
    @db.each 'SELECT * FROM [document] ORDER BY [seq]',
      (err, row) =>
        try
          p = new @types[row.type] {}
          p.__po__ = {}
          delete row.payload.id
          p.__po__[k] = v for k,v of JSON.parse row.payload
          p.id = row.id
          p.createdAt = moment row.createdAt
          p.updatedAt = moment row.updatedAt
          p.type = row.type
          @push p
        catch error
          console.log 'load: ', error.message
      (err) =>
        for id, each of @index
          for name, value of each.__po__
            each[name] = value unless name is '_links'
            if name is '_links'
              for link, content of value
                if typeof content is 'string'
                  each[link] = @index[content]
                else if content instanceof Array
                  each[link] = (@index[k] for k in content)

        callback() if callback?

  json: (target) ->
    po = {}
    po.id = target.id
    links = {}
    for name, value of target
      continue unless name in target.fields
      if value instanceof Model
        links[name] = value.id
      else if value instanceof Array && value.length > 0 && value[0] instanceof Model
        links[name] = (p.id for p in value)
      else
        po[name] = value
    po._links = links if Object.keys(links).length > 0
    JSON.stringify po, null, 2

exports.Model = class Model extends events.EventEmitter
  constructor: ->
    Object.defineProperty this, '_fromNow', enumerable: true, get: -> @createdAt.fromNow()

  @create: -> Store.instance().push (new(@) arguments...)
  @persist: (fields...) ->
    Store.instance().types[this.name] = this
    @::fields = fields
  save: -> @emit 'save', this
  delete: -> @emit 'delete', this
  @find: (condition) ->
    if condition?
      if condition instanceof Function
        v for k,v of Store.instance()[this.name] when condition v
      else if typeof condition is 'string'
        Store.instance().index[condition]
    else
      v for k,v of Store.instance()[this.name] if Store.instance()[this.name]?

  @findone: (condition) ->
    if condition?
      result = null
      for k,v of Store.instance()[this.name]
        if condition v
          result = v
          break
      result
