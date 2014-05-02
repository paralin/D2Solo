Accounts.onCreateUser (options, user)->
  user.steamtracks = {authorized: false}
  user.profile = {name: user.services.steam.username}
  user

Meteor.publish "userData", ->
  Meteor.users.find
    _id: @userId
 
Meteor.startup ->
  cursor = Meteor.users.find({}, {fields: {'_id': 1}})
  if !Metrics.findOne({_id: "users"})?
    Metrics.insert {_id: "users", count: cursor.count()}
  cursor.observeChanges
    _suppress_initial: true
    added: ->
      Metrics.update {_id: "users"}, {$set: {count: cursor.count()}}
