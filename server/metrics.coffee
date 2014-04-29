Meteor.startup ->
  Metrics.remove({})
  Metrics.insert
    _id: "queue"
    count: 0
