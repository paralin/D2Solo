_.deepExtend = (destination, source) ->
  for property of source
    if typeof source[property] is "object"
      destination[property] = destination[property] or {}
      _.deepExtend destination[property], source[property]
    else
      destination[property] = source[property]
  destination
