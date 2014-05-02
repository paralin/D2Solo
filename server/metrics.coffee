Meteor.startup ->
  Metrics.remove({_id: "queue"})
  queueMetric =
    _id: "queue"
    count: 0
  for id of Regions
    queueMetric[id] = 0
  Metrics.insert queueMetric
  if !Metrics.findOne({_id:"stats"})?
    Metrics.insert
      _id: "stats"
      lobbyCount: 53
@incLobbyCount = ->
  Metrics.update {_id: "stats"}, {$inc: {lobbyCount: 1}}
