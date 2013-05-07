esp = require 'esp'

Post = require '../model/post'
User = require '../model/user'

esp.route ->
  @put '/post', ->
    data = ''
    @request.setEncoding 'utf-8'
    @request.on 'data', (chunk) -> data += chunk
    @request.on 'end', =>
      try
        p = JSON.parse data
        if p.content?.trim().length > 0
          po = Post.create p.content.trim()

          user = User.find @cookie.token if @cookie?.token?
          unless user?
            user = User.findone (p) -> p.name is 'public'
          po.belongsTo = user
          po.save()
          @json po, 201
        else
          throw new Error 'require content'
      catch error
        console.log error.message
        @html error.message, 400

  @delete '/post/:id', ->
    p = Post.findone @id
    try
      p.delete()
      @html '', 204
    catch error
      console.log error.message
      @html error.message, 404

  @get '/post/:id', ->
    @view 'post_detail', Post.find @id
