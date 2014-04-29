Meteor.publish "matchUser", ->
  return [] if !@userId?
  user = Meteor.users.findOne _id: @userId
  return [] if !user? || !user.queue? || !user.queue.matchUser?
  Meteor.users.find {_id:user.queue.matchUser}, {fields: {profile: 1, 'services.steam': 1}}
