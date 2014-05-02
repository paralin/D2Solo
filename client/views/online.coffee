Template.onlineCount.count = ->
  metric = Metrics.findOne {_id: "ausers"}
  return "?" if !metric?
  metric.count
Template.onlineCount.pcount = ->
  metric = Metrics.findOne({_id: "pusers"})
  return "?" if !metric?
  return metric.count+""
