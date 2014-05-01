Template.lobbyCount.count = ->
  metric = Metrics.findOne _id: "stats"
  return "?" if !metric?
  metric.lobbyCount
