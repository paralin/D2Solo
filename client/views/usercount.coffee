Template.usercount.count = ->
  metric = Metrics.findOne({_id: "users"})
  return "?" if !metric?
  return metric.count
