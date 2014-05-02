Template.onlineCount.count = ->
  metric = Metrics.findOne {_id: "ausers"}
  return "?" if !metric?
  metric.count
