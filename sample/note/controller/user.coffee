qs = require 'querystring'
md5 = require 'md5'
util = require 'util'
esp = require 'esp'

mailer = require 'nodemailer'
smtpTransport = mailer.createTransport 'SMTP', service: 'Yahoo',
  auth: { user: 'h705c@yahoo.com', pass: 'your-password' }

User = require '../model/user'

esp.route ->
  @get '/login', -> @view 'login'

  @post '/login', ->
    data = ''
    @request.setEncoding 'utf-8'
    @request.on 'data', (chunk) -> data += chunk
    @request.on 'end', =>
      content = qs.parse data
      user = User.findone (p) -> p.email is content.email
      if user?.password == content.password
        util.log "login OK: #{user.email}"
        @setCookie email: user.email, token: user.id
        @redirect '/'
      else
        console.log 'login Failed: ', user.email
        @clearCookie()
        @redirect '/login'

  @get '/logout', ->
    @clearCookie()
    @redirect '/'

  @get '/signup/:email', ->
    @view 'activate', email: @email

  @post '/signup', ->
    data = ''
    @request.setEncoding 'utf-8'
    @request.on 'data', (chunk) -> data += chunk
    @request.on 'end', =>
      email = qs.parse(data).email

      mailContent =
          from: "smooth network <h705c@yahoo.com>"
          to: email
          subject: "Invitation to Smooth Network, your online notebook"
          text: """
                  Hello,

                  We appreciate you signing up for smooth network.

                  To activate your account please click the link below:
                  http://localhost:7005/signup/#{encodeURIComponent(email)}

                  Enjoy, 
                  The Smooth Team
                """
      # send mail with defined transport object
      smtpTransport.sendMail mailContent, (err, res) ->
        if err? then console.log err else console.log "Message sent: #{res.message}"
        smtpTransport.close()

      @redirect '/login'
