@matchFoundSound = new buzz.sound('https://s3-us-west-2.amazonaws.com/d2solo/match_ready.ogg')

Meteor.startup ->
  Meteor.autorun ->
    user = Meteor.user()
    return if !user?
    queue = user.queue
    return if !queue?
    return if !queue.matchFound? || !queue.matchFound
    matchFoundSound.play()
