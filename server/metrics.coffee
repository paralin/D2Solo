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
  Metrics.remove({_id: "ausers"})
  Metrics.insert
    _id: "ausers"
    count: 0
  Meteor.users.find({'status.online': true}, {fields: {_id: 1}}).observeChanges
    added: ->
      Metrics.update {_id: "ausers"}, {$inc: {count: 1}}
    removed: ->
      Metrics.update {_id: "ausers"}, {$inc: {count: -1}}
  Metrics.remove {_id: "pusers"}
  Metrics.insert
    _id: "pusers"
    count: 0
  Meteor.users.find({'status.online': true, 'queue.matchFound': true}, {fields: {_id: 1}}).observeChanges
    added: ->
      Metrics.update {_id: "pusers"}, {$inc: {count: 1}}
    removed:
      Metrics.update {_id: "pusers"}, {$inc: {count: -1}}
@incLobbyCount = ->
  Metrics.update {_id: "stats"}, {$inc: {lobbyCount: 1}}

