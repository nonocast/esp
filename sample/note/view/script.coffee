$ ->
  $('.delete_post').click onDeletePost
  $('.send_post').click ->
    @content = $('.post_form textarea').val()
    $.ajax
      url: '/post', type: 'PUT', data: JSON.stringify(content: @content),
      success: (data, status) =>
        po = $ """<li class='post'>
            <div>#{data.content}</div>
            <div class='toolbar'>刚刚<a style='float:right' link='#{data.link}' class='delete_post' href='javascript:void(0);'>删除</a></div>
        </li>"""
        $('.posts').prepend po
        $('.delete_post', po).click onDeletePost

        $('.post_form textarea').val('')
      statusCode:
        400: -> alert 'error'

onDeletePost = ->
  $.ajax
    url: $(this).attr('link'), type: 'DELETE',
    success: (data, status) =>
      $(this).parents('li').remove()
    statusCode:
      404: -> alert 'error'
