doctype 5
html ->
  head ->
    meta charset: 'utf-8'
    meta name:'viewport', content: 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0'
    title 'smooth'
    link rel: 'stylesheet', href: '/style.css'
    script src: 'http://ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js'
    script src: '/jquery.md5.js'
    script src: '/script.js'

  body ->
    div 'mainbar', ->
      div 'logo', ->
        a href:'/', -> 'SmoothNetwork'
      div 'topbar', ->
        if 'public' is @name
          a href:'/login', -> 'log in'
        else
          span style:'color:#777;margin-right:15px;font-weight:bold;', -> @name
          a href:'/logout', -> 'log out'

    div 'wrapper', ->
      header ->
        h1 @name

      div 'post_form', ->
        textarea name:'post_content', ->
        div ->
          button 'send_post', -> 'Send'

      div 'wrapper2', ->
        div 'search', ->
          div ->
            input type:'text', ->
            button -> '搜索'

        ul 'posts', style:'padding:0 10px 0 5px;', ->
          for each in @posts
            li 'post', =>
              div ->
                each.content
              div 'toolbar', ->
                text each._fromNow
                a 'delete_post', href: 'javascript:void(0);', link:each._uri, style: 'float:right;', -> '删除'
