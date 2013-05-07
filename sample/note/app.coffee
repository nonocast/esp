#!/usr/bin/env coffee

md5 = require 'md5'
esp = require 'esp'
fs = require 'fs'

User = require './model/user'
Post = require './model/post'

require './controller/data'
require './controller/user'
require './controller/post'

esp.route ->
  @get '/', ->
    user = User.find @cookie.token if @cookie?.token?
    unless user?
      user = User.findone (p) -> p.name is 'public'

    @view 'index', name: user.name, posts: user.findPosts() or []

esp.run 7005
