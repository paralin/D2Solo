Template.matchmaking.rendered = ->
  $("#queueRangeSlider").slider
    min: 0
    max: 6000
    step: 100
    value: [2900, 3200]
