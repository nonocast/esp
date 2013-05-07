doctype 5
html ->
  head ->
    meta charset: 'utf-8'
    meta name:'viewport', content: 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0'
    title 'login'
    link rel: 'stylesheet', href: '/style.css'
    script src: 'http://ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js'
    script src: '/jquery.md5.js'
    coffeescript ->
      $ ->
        $('#buttonLogin').click ->
          email = $('input#email').val()
          password = $.md5 $('input#password').val()
          $("<form action:'/login' method='POST'><input name='email' value='#{email}'><input name='password' value='#{password}'></form>").submit()
  
  body 'login', ->
    div 'mainbar', ->
      div 'logo', ->
        a href:'/', -> 'SmoothNetwork'
      div 'topbar', ->
        a href:'/login', -> 'log in'

    div 'wrapper', ->
      div id:'panel1', ->
        header ->
          h1 'log in'
        
        section ->
          form name:'formLogin', method:'POST', action:'/login', ->
            p ->
              label for:'email', -> 'Email'
              input id:'email', name:'email', type:'text', required:'required', ->

            p ->
              label for:'password', -> 'Password'
              input id:'password', name:'password', type:'password', required:'required', ->

            div 'footer', ->
              div 'sign', ->
                p ->
                  span "Don't have a smooth network account?"
                  a href:'#', -> 'Create one new'

              button id:'buttonLogin', type:'button', -> 'Login'

      div id:'panel2', ->
        header ->
          h1 'sign up'
        
        section ->
          form name:'formSignUp', method:'POST', action:'/signup', ->
            p ->
              label for:'email', -> 'Email'
              input id:'email', name:'email', type:'text', required:'required', ->

            div 'footer', ->
              div 'sign',style:'width:400px;', ->
                p ->
                  span style:'display:block;', -> "Registration mail will sent to your mailbox."
                  span "Check your mail for the link to complete your registration."

              button id:'buttonSignUp', type:'submit', -> 'join'

      div id:'panel3', ->
        header ->
          h1 'Account Recovery'
        
        section ->
          form name:'formRecovery', method:'POST', action:'/login', ->
            p ->
              label for:'email', -> 'Email'
              input id:'email', name:'email', type:'text', required:'required', ->

            div 'footer', ->
              div 'sign',style:'width:300px;', ->
                p ->
                  span style:'display:block;', -> "Leave your email address,"
                  span "and we will send you instructions to get you signed in."

              button id:'buttonSignUp', type:'submit', -> 'recovery'
