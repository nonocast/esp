esp = require 'esp'
Post = require './post'

class User extends esp.Model
  @persist 'name', 'email', 'password'

  constructor: (@name, @email, @password, @posts=[]) ->
    super

  findPosts: -> (Post.find (p) => p.belongsTo == this).reverse()

exports = module.exports = User
