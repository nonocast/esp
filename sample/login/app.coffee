esp = require 'esp'

esp.auth '/login', -> 'Cao Hui' if @cookie?.token is 'nonocast'

esp.route ->
  @get '/', -> @html """
    <h1>#{@user}</h1><p><a href='/logout'>logout</a></p>
    """

  @get '/login', -> @html """
    <h1>press the button to login</h1>
    <form method='post' action='/login'>
      <input type='submit' value='login'></input>
    </form>
    """

  @post '/login', ->
    @setCookie token: 'nonocast'
    @redirect '/'

  @get '/logout', ->
    @clearCookie()
    @redirect '/'

  @get '/public', ->
    @html 'without auth'
  , public: true

esp.run 7005
