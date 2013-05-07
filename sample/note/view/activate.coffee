doctype 5
html ->
  head ->
    meta charset: 'utf-8'
    meta name:'viewport', content: 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0'
    title 'login'
    link rel: 'stylesheet', href: '/style.css'
    script src: 'http://ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js'
    script src: '/jquery.md5.js'
  
  body 'login', ->
    div 'mainbar', ->
      div 'logo', ->
        a href:'/', -> 'SmoothNetwork'
      div 'topbar', ->
        a href:'/login', -> 'log in'

    div 'wrapper', ->
      header ->
        h1 "activate for #{@.email}"
        
      section ->
        form name:'formActivate', method:'POST', action:'/actviate', ->
          p ->
            label for:'name', -> 'Name'
            input id:'name', name:'name', type:'text', required:'required', ->

          p ->
            label for:'password', -> 'Password'
            input id:'password', name:'password', type:'password', required:'required', ->

          p ->
            label for:'passwordAgain', -> 'Password Again'
            input id:'passwordAgain', name:'passwordAgain', type:'password', required:'required', ->

          div 'footer', ->
            div 'sign', ->
              p ->
                span "Don't have a smooth network account?"
                a href:'#', -> 'Create one new'

            button id:'buttonActivate', type:'button', -> 'Activate'

