fs = require 'fs'
qs = require 'querystring'
url = require 'url'
path = require 'path'
kup = require './coffeefilter'
util = require 'util'
file = new (require 'node-static').Server './public'

exports.Server = class Server
  constructor: (@router) ->
    @server = require('http').createServer()
    @server.on 'request', (request, response) =>
      try
        @router.route(request, response)
      catch error
        content = error.message
        response.writeHead 500, 'Content-Length': Buffer.byteLength(content, 'utf-8')
        response.write content, 'utf-8'
        response.end()

  run: (port) ->
    @server.listen port
    console.log("listening on #{port}")

exports.Router = class Router
  constructor: (callback) -> callback.apply this if callback?
  include: (callback) -> callback.apply this
  get: (pattern, callback, option) -> @push 'GET', pattern, callback, option
  post: (pattern, callback, option) -> @push 'POST', pattern, callback, option
  put: (pattern, callback, option) -> @push 'PUT', pattern, callback, option
  delete: (pattern, callback, option) -> @push 'DELETE', pattern, callback, option
  head: (pattern, callback, option) -> @push 'HEAD', pattern, callback, option
  push: (method, pattern, callback, option) ->
    @patterns = @patterns ? []
    @patterns.push new Pattern(method, pattern, callback, option)
  route: (request, response) ->
    util.log "request #{request.method} #{request.httpVersion} #{request.url}"

    for each in @patterns.slice(0).reverse()
      if each.test request
        pattern = each
        break
    if pattern?
      # util.log pattern.rule
      args = pattern.exec request
      ctx = new Context(request, response, args)
      ctx.user = @auth.apply ctx if @auth?

      if pattern.option?.public
        pattern.callback.apply ctx
      else
        if @auth? and not ctx.user? and request.url isnt @login
          @redirect_login response
        else
          pattern.callback.apply ctx
    else
      file.serve(request, response)

  redirect_login: (response) ->
    if @login?
      response.writeHead 302, 'Location' : @login
      response.end()

class Pattern
  constructor: (@method, @input, @callback, @option) ->
    if @input instanceof RegExp
      @rule = @input
      return

    p = if Array.isArray(@input) then '('+@input.join('|')+')' else @input
    p = p.replace /:([^/])+/g, ($) =>
      @keys = @keys ? []
      @keys.push $.slice 1
      return "([^/]+)"

    @rule = new RegExp "^#{p}/?$"

  test: (request) ->
    @method == request.method && @rule.test(url.parse(request.url).pathname)

  exec: (request) ->
    return {} unless @keys?
    m = @rule.exec(url.parse(request.url).pathname)
    result = {}
    for i in [0..@keys.length]
      result[@keys[i]] = decodeURIComponent m[i+1]
    return result

class Context
  constructor: (@request, @response, args) ->
    @[k] = v for k, v of args

    @query = url.parse(@request.url, true).query

    if @request.headers.cookie?
      cookie = @request.headers.cookie
      cookie = qs.parse cookie, ';'
      @cookie = {}
      @cookie[k.trim()] = v for k,v of cookie

  html: (content,code=200) -> @write 'text/html', content, code
  text: (content) -> @write 'text/plain',content
  json: (data, indent=null) -> @write 'application/json; charset=utf-8', JSON.stringify(data, null, indent)
  j: (data, indent=null) -> @write 'application/json; charset=utf-8', JSON.stringify(data, ((k,v) -> if k.slice(0,1) is '_' then undefined else v), indent)
  redirect: (uri) ->
    @response.writeHead 302, 'Location' : uri
    @response.end()

  write: (mime, content, code=200) ->
    @response.writeHead code, {
      'Content-Type': mime,
      'Content-Length': Buffer.byteLength(content, 'utf-8')
    }
    @response.write content, 'utf-8'
    @response.end()

  view: (file, model) ->
    model = model or {}
    model.user = @user.name if @user?

    file = "#{file}.coffee" if path.extname(file).length == 0

    fs.readFile path.join('./view/', file), 'utf-8', (err, content) =>
      unless err?
        ext = path.extname(file).slice 1
        if @[ext]? and ext isnt 'html'
          try
            @[ext] content, model
          catch error
            @html error.message
        else
          @html content
      else
        @html 'Not found', 404

  setCookie: (arg) ->
    @response.setHeader("Set-Cookie", "#{k}=#{v}" for k,v of arg) if arg?

  clearCookie: ->
    @response.setHeader("Set-Cookie", "#{k}=''" for k of @cookie)

  coffee: (template, model={}) ->
    model.settings =
      views: './view'
      format: false
    @html kup.render template, model
