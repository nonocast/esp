esp = require 'esp'
md5 = require 'md5'

Post = require '../model/post'
User = require '../model/user'

esp.route ->
  @get '/data', -> @json esp.store.index, 2

  @put '/init', ->
    User.create 'public', 'public@smooth.com', md5 '000000'
    nonocast = User.create 'nonocast', 'nonocast@gmail.com', md5 '1234%^&*'
    User.create 'tony', 'tony@gmail.com', md5 '123456'
    ###
    for i in [1..10000]
      p = Post.create "hello world, it's post (#{i})"
      p.belongsTo = nonocast
      p.save()
    ###
    @redirect '/data'
