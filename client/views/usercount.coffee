Template.usercount.count = ->
  metric = Metrics.findOne({_id: "users"})
  return "?" if !metric?
  return metric.count+""
Template.usercount.pcount = ->
  metric = Metrics.findOne({_id: "pusers"})
  return "?" if !metric?
  return metric.count+""
