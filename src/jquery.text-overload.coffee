

# Reference jQuery
$ = jQuery

pluginName = 'overload'
document = window.document

elementFactory = (element, value) ->
  element.text(value.val)

class OverloadPlugin 

  MENU_TEMPLATE = "<div class='-sew-list-container' style='display: none; position: absolute;'><ul class='-sew-list'></ul></div>"
  ITEM_TEMPLATE = '<li class="-sew-list-item"></li>'
  KEYS = [40, 38, 13, 27, 9]
  TIME_UNTIL_HIDE = 1000

  constructor: (element, options) ->
    @options = options
    @element = element
    @$element = $(element)
    @$itemList = $(MENU_TEMPLATE)

    @_name = pluginName

    # TODO add tokens and callbacks
    # TODO add callback for values

    # Approach to support multiple lookups 
    # tokens: [{token: '@', lookup: functionReference, select: functionCallback}] 
    # Alternative: [{token: '@', values: [ array of values ], select: functionCallback}]  
    @lookupFilters = {}
    @selectCallbacks = {}
    @tokens = {}

    if @options.tokens?
      for token in @options.tokens
        lookup = @setupFilter(token)
        @lookupFilters[token.token] = lookup if lookup
        @selectCallbacks[token.token] = token.select if token.select?
        @tokens[token.token] = token 
    else 
      token = 
        token: @options.token
        values: @options.values
        lookup: @options.valueLookup

      @lookupFilters[@options.token] = @setupFilter(token)
      @tokens[@options.token] = token
    
    expressionString = '(?:^|\\b|\\s)[' + Object.keys(@tokens).join('|') + ']([\\w.]*)$'
    @expression = new RegExp(expressionString)  

    @reset()
    @cleanupHandle = null
    @init()

  # Sets up the lookup filter for a given token
  # Could be passed in or based on a value list that is passed in 
  setupFilter: (token) ->
    if token.lookup?
      if @options.unique
        return (val) => 
          OverloadPlugin.getUniqueElements(token.lookup(val))
      else 
        return token.lookup
    if (values = token.values)
      (val) => 
        filterItem = (e) =>
          exp = new RegExp('\\W*' + token.token + e.val + '(\\W|$)')
          if(!@options.repeat && @getText().match(exp))
            return false

          return val == "" ||
                e.val.toLowerCase().indexOf(val.toLowerCase()) >= 0 ||
                (e.meta || "").toLowerCase().indexOf(val.toLowerCase()) >= 0
        if @options.unique
          OverloadPlugin.getUniqueElements(values.filter($.proxy(filterItem, @)))
        else 
          values.filter($.proxy(filterItem, @))

  init: ->
    @$element.bind('keyup', $.proxy(@onKeyUp, @))
             .bind('keydown', $.proxy(@onKeyDown, @))
             .bind('focus', $.proxy(@renderElements, @, []))
             .bind('blur', $.proxy(@remove, @))
  reset: ->
    @index = 0
    @matched = false
    @dontFilter = false
    @lastFilter = undefined
    @filtered = []

  next: ->
    @index = (@index + 1) % @filtered.length
    @hightlightItem()
  
  prev: ->
    @index = (@index + @filtered.length - 1) % @filtered.length
    @hightlightItem()

  select: ->
    # TODO set the option with the token
    # the name and value so it can be selected / sent
    @replace(@filtered[@index].val)
    @hideList()

  remove: ->
    @$itemList.fadeOut('slow')

    itemListRemove = ->
      @$itemList.remove()

    @cleanupHandle = window.setTimeout($.proxy(itemListRemove, @), TIME_UNTIL_HIDE)

  replace: (replacement) ->
    startpos = @$element.getCursorPosition()
    separator = if startpos == 1 then '' else ' '

    fullStuff = @getText()
    val = fullStuff.substring(0, startpos)
    val = val.replace(@expression, separator + @options.token + replacement)
    posfix = fullStuff.substring(startpos, fullStuff.length)
    separator2 = if posfix.match(/^\s/) then '' else ' '
    
    finalFight = val + separator2 + posfix
    @setText(finalFight)
    @$element.setCursorPosition(val.length + 1)

  hightlightItem: ->
    @$itemList.find(".-sew-list-item").removeClass("selected")

    if @filtered.length
      container = @$itemList.find(".-sew-list-item").parent()
      element = @filtered[@index].element.addClass("selected")
      scrollPosition = element.position().top
      container.scrollTop(container.scrollTop() + scrollPosition)

  # Called after the list of values are found via the filterList method
  # It renders the values using the elementFactory which produces the list how you want it to look.
  renderElements: (values) ->
    # TODO append to another element
    $("body").append(@$itemList)
    container = @$itemList.find('ul').empty()
    elementSetup = (e, i) =>
      $item = $(ITEM_TEMPLATE)
      @options.elementFactory($item, e)
      containerElement = $item.appendTo(container)
      containerElement.on('click', $.proxy(@onItemClick, @, e))
      e.element = containerElement.on('mouseover', $.proxy(@onItemHover, @, i))

    $.proxy(elementSetup(e,i), @) for i, e of values 
    @index = 0
    if values.length
      @hightlightItem()


  displayList: ->
    return unless @filtered.length
    @$itemList.show()
    element = @$element
    offset = @$element.offset()
    pos = element.getCaretPosition()

    @$itemList.css
      left: offset.left + pos.left
      top: offset.top + pos.top

  hideList: ->
    @$itemList.hide()
    @reset()

  # Called with the value of the lookup without the token
  # For instance, if @blah is typed it searches for blah
  filterList: (val, lookup) ->
    return if (val == @lastFilter) 
    @lastFilter = val
    @$itemList.find(".-sew-list-item").remove()

    vals = @filtered = lookup(val)
    if vals.length 
      @renderElements(vals)
      @$itemList.show()
    else
      @hideList()

  getText: ->
    @$element.val() || @$element.text()

  setText: (text) ->
    if @$element.prop('tagName').match(/input|textarea/i)
      @$element.val(text)
    else
      # poors man sanitization
      text = $("<span>").text(text).html().replace(/\s/g, '&nbsp')
      @$element.html(text)

  onKeyUp: (e) ->
    startpos = @$element.getCursorPosition()
    text = @getText().substring(0, startpos)
    matches = text.match(@expression)
    if !matches && @matched
      @matched = false
      @dontFilter = false
      @hideList()
      return

    if matches
      if !@matched
        @displayList()
        @lastFilter = "\n"
        @matched = true
      else if !@dontFilter
        lookup = @lookupFilters[@options.token]
        @filterList(matches[1], lookup)
        @displayList()

  onKeyDown: (e) ->
    listVisible = @$itemList.is(":visible")
    return if !listVisible || (KEYS.indexOf(e.keyCode) < 0)

    switch e.keyCode
      when 9, 13 then @select()
      when 40 then @next()
      when 38 then @prev()
      when 27
        @$itemList.hide()
        @dontFilter = true
    e.preventDefault()

  onItemClick: (element, e) ->
    window.clearTimeout(@cleanupHandle) if @cleanupHandle
    @replace(element.val)
    @hideList()

  onItemHover: (index, e) ->
    @index = index
    @hightlightItem()

OverloadPlugin.getUniqueElements = (elements) ->
  uniqueElements = []
  for element in elements
    hasElement = uniqueElements.some((unique) ->
      unique.val == element.val
    )
    continue if hasElement
    uniqueElements.push element  
  uniqueElements

# Adds plugin object to jQuery
$.fn.extend
  overload: (options) ->
    # Default settings
    settings =
      token: '@',
      elementFactory: elementFactory,
      values: [],
      unique: false,
      repeat: true,
      debug: false

    # Merge default settings with options.
    settings = $.extend settings, options

    return @each ->
      if !$.data(@, 'plugin_' + pluginName)
        $.data(@, 'plugin_' + pluginName, new OverloadPlugin(@, settings))
