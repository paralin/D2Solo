Meteor.startup ->
  Deps.autorun ->
    user = Meteor.user()
    return if !user? || !user.queue? || !user.queue.matchUser?
    Meteor.subscribe "matchUser"
