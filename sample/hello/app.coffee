#!/usr/bin/env coffee
esp = require 'esp'
esp.route ->
  @get '/', -> @html "<h1>hello world</h1>"
esp.run 7005
