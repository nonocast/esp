# **CoffeeKup** lets you to write HTML templates in 100% pure
# [CoffeeScript](http://coffeescript.org).
#
# You can run it on [node.js](http://nodejs.org) or the browser, or compile your
# templates down to self-contained javascript functions, that will take in data
# and options and return generated HTML on any JS runtime.
#
# The concept is directly stolen from the amazing
# [Markaby](http://markaby.rubyforge.org/) by Tim Fletcher and why the lucky
# stiff.

if window?
  coffeefilter = window.CoffeeKup = {}
  coffee = if CoffeeScript? then CoffeeScript else null
else
  coffeefilter = exports
  coffee = require 'coffee-script'
  fs = require 'fs'

coffeefilter.version = '0.3.1edge'

class TemplateError extends Error
  constructor: (@message) ->
    Error.call this, @message
    Error.captureStackTrace this, arguments.callee
    name: 'TemplateError'

class TemplateCompilationError extends Error
  constructor: (@message) ->
    Error.call this, @message
    Error.captureStackTrace this, arguments.callee
    name: 'TemplateCompilationError'

# Values available to the `doctype` function inside a template.
# Ex.: `doctype 'strict'`
coffeefilter.doctypes =
  'default': '<!DOCTYPE html>'
  '5': '<!DOCTYPE html>'
  'xml': '<?xml version="1.0" encoding="utf-8" ?>'
  'transitional': '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">'
  'strict': '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">'
  'frameset': '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">'
  '1.1': '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">',
  'basic': '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd">'
  'mobile': '<!DOCTYPE html PUBLIC "-//WAPFORUM//DTD XHTML Mobile 1.2//EN" "http://www.openmobilealliance.org/tech/DTD/xhtml-mobile12.dtd">'
  'ce': '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "ce-html-1.0-transitional.dtd">'

# CoffeeScript-generated JavaScript may contain anyone of these; but when we
# take a function to string form to manipulate it, and then recreate it through
# the `Function()` constructor, it loses access to its parent scope and
# consequently to any helpers it might need. So we need to reintroduce these
# inside any "rewritten" function.
coffeescript_helpers = """
  var __slice = Array.prototype.slice;
  var __hasProp = Object.prototype.hasOwnProperty;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  var __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype;
    return child; };
  var __indexOf = Array.prototype.indexOf || function(item) {
    for (var i = 0, l = this.length; i < l; i++) {
      if (this[i] === item) return i;
    } return -1; };
""".replace(/\n/g, '').replace(/\t/g, ' ')

# Private HTML element reference.
# Please mind the gap (1 space at the beginning of each subsequent line).
elements =
  # Valid HTML 5 elements requiring a closing tag.
  # Note: the `var` element is out for obvious reasons, please use `tag 'var'`.
  regular: 'a abbr address article aside audio b bdi bdo blockquote body button
 canvas caption cite code colgroup datalist dd del details dfn div dl dt em
 fieldset figcaption figure footer form h1 h2 h3 h4 h5 h6 head header hgroup
 html i iframe ins kbd label legend li map mark menu meter nav noscript object
 ol optgroup option output p pre progress q rp rt ruby s samp script section
 select small span strong style sub summary sup table tbody td textarea tfoot
 th thead time title tr u ul video'

  # Valid self-closing HTML 5 elements.
  void: 'area base br col command embed hr img input keygen link meta param
 source track wbr'

  obsolete: 'applet acronym bgsound dir frameset noframes isindex listing
 nextid noembed plaintext rb strike xmp big blink center font marquee multicol
 nobr spacer tt'

  obsolete_void: 'basefont frame'

# Create a unique list of element names merging the desired groups.
merge_elements = (args...) ->
  result = []
  for a in args
    for element in elements[a].split ' '
      result.push element unless element in result
  result

# Public/customizable list of possible elements.
# For each name in this list that is also present in the input template code,
# a function with the same name will be added to the compiled template.
coffeefilter.tags = merge_elements 'regular', 'obsolete', 'void', 'obsolete_void'

# Public/customizable list of elements that should be rendered self-closed.
coffeefilter.self_closing = merge_elements 'void', 'obsolete_void'

# This is the basic material from which compiled templates will be formed.
# It will be manipulated in its string form at the `coffeefilter.compile` function
# to generate the final template function.
skeleton = (data = {}) ->
  # Whether to generate formatted HTML with indentation and line breaks, or
  # just the natural "faux-minified" output.
  data.format ?= off

  # Whether to autoescape all content or let you handle it on a case by case
  # basis with the `h` function.
  data.autoescape ?= off

  # Internal coffeefilter stuff.
  __cf =
    # data
    is_ceding: false

    root_node:
      id: '__root_node'
      buffer: []
      children_pos: {}
      parent: null

    current_node: null
    nodes: null
    base: null

    tabs: 0

    # render methods, not to be called from inside skeleton
    render: ->
      if @base?
        @render_with_base()
      else
        @render_without_base()

    render_without_base: ->
      @render_node @root_node

    render_with_base: ->
      @update_node @root_node
      @base.render()

    update_node: (node) ->
      if node.parent?
        same_node = @base.nodes[node.id]
        if same_node?
          # the same node exists in base, copy the parent from it
          node.parent = same_node.parent
        # write this node to base, either overwriting existing
        # or writing a new node
        @base.nodes[node.id] = node
      for child_id of node.children_pos
        child = @nodes[child_id]
        @update_node child

    render_node: (node) ->
      for child_id of node.children_pos
        child = @nodes[child_id]
        child_content = @render_node child
        node.buffer[node.children_pos[child_id]] = child_content
      node.buffer.join ''

    # content-writing methods
    # Adapter to keep the builtin tag functions DRY.
    tag: (name, args) ->
      combo = [name]
      combo.push i for i in args
      tag.apply data, combo

    repeat: (string, count) ->
      Array(count + 1).join string

    indent: ->
      text @repeat('  ', @tabs) if data.format

    esc: (txt) ->
      if data.autoescape then h(txt) else String(txt)

    write_idclass: (str) ->
      classes = []

      for i in str.split '.'
        if '#' in i
          id = i.replace '#', ''
        else
          classes.push i unless i is ''

      text " id=\"#{id}\"" if id

      if classes.length > 0
        text " class=\""
        for c in classes
          text ' ' unless c is classes[0]
          text c
        text '"'

    write_attrs: (obj, prefix = '') ->
      for k, v of obj
        # `true` is rendered as `selected="selected"`.
        v = k if typeof v is 'boolean' and v

        # Functions are rendered in an executable form.
        v = "(#{v}).call(this);" if typeof v is 'function'

        # Prefixed attribute.
        if typeof v is 'object' and v not instanceof Array
          # `data: {icon: 'foo'}` is rendered as `data-icon="foo"`.
          @write_attrs(v, prefix + k + '-')
        # `undefined`, `false` and `null` result in the attribute not being rendered.
        else if v
          # strings, numbers, arrays and functions are rendered "as is".
          text " #{prefix + k}=\"#{@esc(v)}\""

    write_contents: (contents) ->
      switch typeof contents
        when 'string', 'number', 'boolean'
          text @esc(contents)
        when 'function'
          text '\n' if data.format
          @tabs++
          result = contents.call data
          if typeof result is 'string'
            @indent()
            text @esc(result)
            text '\n' if data.format
          @tabs--
          @indent()

    write_tag: (name, idclass, attrs, contents) ->
      @indent()

      text "<#{name}"
      @write_idclass(idclass) if idclass
      @write_attrs(attrs) if attrs

      if name in @self_closing
        text ' />'
        text '\n' if data.format
      else
        text '>'

        @write_contents(contents)

        text "</#{name}>"
        text '\n' if data.format

      null

  __cf.current_node = __cf.root_node
  __cf.nodes =
    '__root_node': __cf.root_node

  # functions available to the template writer
  # "built-in" tag functions available as well
  tag = (name, args...) ->
    for a in args
      switch typeof a
        when 'function'
          contents = a
        when 'object'
          attrs = a
        when 'number', 'boolean'
          contents = a
        when 'string'
          if args.length is 1
            contents = a
          else
            if a is args[0]
              idclass = a
            else
              contents = a

    __cf.write_tag(name, idclass, attrs, contents)

  h = (txt) ->
    String(txt).replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')

  doctype = (type = 'default') ->
    text __cf.doctypes[type]
    text '\n' if data.format

  cede = (f) ->
    temp_buffer = []
    __cf.is_ceding = true
    old_buffer = __cf.current_node.buffer
    __cf.current_node.buffer = temp_buffer
    f()
    __cf.current_node.buffer = old_buffer
    __cf.is_ceding = false
    temp_buffer.join ''

  text = (txt) ->
    __cf.current_node.buffer.push String(txt)
    null

  comment = (cmt) ->
    text "<!--#{cmt}-->"
    text '\n' if data.format

  coffeescript = (param) ->
    switch typeof param
      # `coffeescript -> alert 'hi'` becomes:
      # `<script>;(function () {return alert('hi');})();</script>`
      when 'function'
        script "#{__cf.coffeescript_helpers}(#{param}).call(this);"
      # `coffeescript "alert 'hi'"` becomes:
      # `<script type="text/coffeescript">alert 'hi'</script>`
      when 'string'
        script type: 'text/coffeescript', -> param
      # `coffeescript src: 'script.coffee'` becomes:
      # `<script type="text/coffeescript" src="script.coffee"></script>`
      when 'object'
        param.type = 'text/coffeescript'
        script param

  # Conditional IE comments.
  ie = (condition, contents) ->
    __cf.indent()

    text "<!--[if #{condition}]>"
    __cf.write_contents(contents)
    text "<![endif]-->"
    text '\n' if data.format

  extend = (base) ->
    if __cf.root_node.buffer.length != 0
      throw new TemplateError "Calls to base need to be first in your template"
    if __cf.base?
      throw new TemplateError "You can only inherit from one template"

    if typeof base is 'string'
      base_template = data.__cf.compile data.settings.views + "/" + base + ".coffee", data
    else
      base_template = data.__cf.compile(base, data)
    __cf.base = base_template data

  block = (id, contents) ->
    node =
      id: id
      buffer: []
      children_pos: {}
      parent: __cf.current_node
    node.parent.children_pos[id] = node.parent.buffer.length
    text "[Block: #{id}]"
    __cf.nodes[id] = node
    __cf.current_node = node
    __cf.write_contents contents
    __cf.current_node = node.parent

  _date_function_helper = (d, format, type) ->
    if not format?
      format = data.__cf.settings["#{type}_format"]
    data.__cf.settings.datetime_function(d, format, type)


  parse_date = (d, format = null) ->
    _date_function_helper d, format, 'date'

  parse_datetime = (d, format = null) ->
    _date_function_helper d, format, 'datetime'

  parse_time = (d, format = null) ->
    _date_function_helper d, format, 'time'

  render_date = (d, format = null) ->
    text parse_date d, format

  render_datetime = (d, format = null) ->
    text parse_datetime d, format

  render_time = (d, format = null) ->
    text parse_time d, format

  null



cache = {}
# Compiles a template into a standalone JavaScript function.
coffeefilter.compile = (template, options = {}) ->
  use_cache = coffeefilter.settings.cache ?= off

  try
    endswith = (str, end) ->
      str.length >= end.length and str.substr(-end.length) == end

    # The template can be provided as either a function, a filename, or a
    # CoffeeScript string (in the latter case, the CoffeeScript compiler must
    # be available).
    if typeof template is 'function'
      filename = "[Some function]"
      use_cache = false
      template = String(template)
    else if typeof template is 'string' and coffee?
      if endswith template, '.coffee'
        filename = template
        if use_cache and cache[filename]?
          return cache[filename]
        else
          template = fs.readFileSync filename, 'utf8'
      else
        filename = "[Inline template]"
        use_cache = false

      template = coffee.compile template, bare: yes
      template = "function(){#{template}}"
    else
      throw new TemplateCompilationError "Unknown template, type: #{typeof template}, template: #{template}"

    compiled_template = make_template_function template, options

    if use_cache
      cache[filename] = compiled_template
  catch e
    throw e

  compiled_template


make_template_function = (template, options = {}) ->
  # Add a function for each tag this template references. We don't want to have
  # all hundred-odd tags wasting space in the compiled function.
  tag_functions = ''
  tags_used = []

  for t in coffeefilter.tags
    if template.indexOf(t) > -1
      tags_used.push t

  embeds = get_embed_strings()

  # hardcode
  hardcoded_locals = ''
  
  if options.hardcode
    for k, v of options.hardcode
      if typeof v is 'function'
        # Make sure these functions have access to `data` as `@/this`.
        hardcoded_locals += "var #{k} = function(){return (#{v}).apply(data, arguments);};"
      else hardcoded_locals += "var #{k} = #{JSON.stringify v};"

  for t in coffeefilter.tags
    if hardcoded_locals.indexOf(t) > -1
      tags_used.push t

  # Main function assembly.
  code = embeds.get_active_tag_functions(tags_used) + hardcoded_locals + embeds.skeleton + ";\n"

  # If `locals` is set, wrap the template inside a `with` block. This is the
  # most flexible but slower approach to specifying local variables.
  code += 'if(!data.locals){'
  code += "(#{template}).call(data);"
  code += '}else{'
  code += 'with(data.locals){'
  code += "(#{template}).call(data);"
  code += '}}'
  code += "return __cf;"

  new Function('data', code)


embed_strings = null

get_embed_strings = ->
  if embed_strings?
    return embed_strings

  # Stringify functions and unwrap it from its enclosing `function(){}`, then
  unwrap_func = (f) ->
    r = String(f)
      .replace(/function\s*\(.*\)\s*\{/, '')
      .replace(/return null;\s*\}$/, '')
    r

  s = unwrap_func skeleton
  s = coffeescript_helpers + s
  s += "__cf.doctypes = #{JSON.stringify coffeefilter.doctypes};"
  s += "__cf.coffeescript_helpers = #{JSON.stringify coffeescript_helpers};"
  s += "__cf.self_closing = #{JSON.stringify coffeefilter.self_closing};"

  tag_functions = {}
  for t in coffeefilter.tags
    tag_functions[t] = "#{t} = function(){return __cf.tag('#{t}', arguments);};"

  embed_strings =
    skeleton: s
    tag_functions: tag_functions

    get_active_tag_functions: (used_tags) ->
      ts = "var #{used_tags.join ','};"
      ts += (@tag_functions[t] for t in used_tags).join ''
      ts

  embed_strings



# Template in, HTML out. Accepts functions or strings as does `coffeefilter.compile`.
#
coffeefilter.render = (filename, data = {}) ->
  # embed a reference to the compile function
  data.__cf =
    compile: coffeefilter.compile
    settings: coffeefilter.settings

  tpl = coffeefilter.compile filename, data

  try
    (tpl data).render()
  catch e then throw new TemplateError "Error rendering #{filename}: #{e.message}"


coffeefilter.default_date_function = (date, format, type) ->
  return date

coffeefilter.settings =
  cache: false

  # dates and times
  datetime_function: coffeefilter.default_date_function
  date_format: "YYYY-MM-DD"
  datetime_format: "YYYY-MM-DD HH:mm"
  time_format: "HH:mm"

coffeefilter.configure = (new_settings = {}) ->
  set = (key) ->
    coffeefilter.settings[key] = new_settings[key] or coffeefilter.settings[key]

  set "cache"
  set "datetime_function"
  set "date_format"
  set "datetime_format"
  set "time_format"


unless window?
  coffeefilter.adapters =
    # Legacy adapters for when CoffeeKup expected data in the `context` attribute.
    simple: coffeefilter.render
    meryl: coffeefilter.render
    express: (filename, data, callback) ->
      if typeof data == 'function'
        [callback, data] = [data, callback]
      if data == null
        data = {}
      str = coffeefilter.render filename, data
      callback null, str
