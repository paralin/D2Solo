Meteor.startup ->
  Metrics.remove({_id: "queue"})
  Metrics.insert
    _id: "queue"
    count: 0
  if !Metrics.findOne({_id:"stats"})?
    Metrics.insert
      _id: "stats"
      lobbyCount: 53
@incLobbyCount = ->
  Metrics.update {_id: "stats"}, {$inc: {lobbyCount: 1}}
