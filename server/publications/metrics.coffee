Meteor.publish "metrics", ->
  Metrics.find()
