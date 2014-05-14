Meteor.methods
  "allNotify": (message)->
    return if !@userId?
    user = Meteor.users.findOne {_id: @userId}
    return if user.services.steam.id isnt "76561198029304414"
    STracks.sendRequest true, "notify", {message: message, broadcast: true}
