Accounts.onCreateUser (options, user)->
  user.steamtracks = {authorized: false}
  user.profile = {name: user.services.steam.username}
  user

Meteor.publish "userData", ->
  Meteor.users.find
    _id: @userId
