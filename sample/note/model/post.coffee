esp = require 'esp'

class Post extends esp.Model
  @persist 'content', 'belongsTo'
  constructor: (@content) ->
    super
    Object.defineProperty this, '_uri', get: -> "/post/#{@id}"

exports = module.exports = Post
