@steamidconvert = (Meteor.require "steamidconvert")()
@STracks = new SteamTracks "KBYkKGacGzZRZye7KPU6", "DBvaNuoKkWvyKX8GKmmw0VlTHvKs7wMH0X7ypKqC"

@STracksTokens = new Meteor.Collection "strackstokens"

@generateSTracksToken = (user)->
  steamID32 = steamidconvert.convertToText user.services.steam.id
  steamID32 = parseInt steamID32.split(":")[2]
  steamID32 = steamID32*2+1
  token = STracks.generateSignupToken null
  user.steamtracks.token = token
  Meteor.users.update({_id: user._id}, {$set: {steamtracks: user.steamtracks}})
  console.log "Token for "+steamID32+" is "+token
  STracksTokens.insert {_id: token, user: user._id}
  token

Router.map ->
  @route "strackscb",
    where: 'server'
    path: 'steamtracks/callback'
    action: ->
      token = @params.token
      if !token?
        @response.writeHead 200, {'Content-Type': 'text/html'}
        @response.end "You need a token to complete this request."
        return
      t = STracksTokens.findOne _id:token
      if !t?
        @response.end "Invalid token."
        return
      user = Meteor.users.findOne _id:t.user
      info = STracks.ackSignupFinish token
      status = STracks.getSignupStatus token
      if status.status is "declined"
        STracksTokens.remove _id: token
        @response.end "You have delined the steamtracks request."
        return
      if status.status isnt "accepted"
        @response.writeHead 200, {'Content-Type': 'text/html'}
        @response.end "The signup process isn't finished yet (token pending still)."
        return
      delete user.steamtracks['token']
      user.steamtracks.authorized = true
      user.steamtracks.info = info.userinfo
      Meteor.users.update {_id:t.user}, {$set: {steamtracks: user.steamtracks}}

Meteor.methods
  "beginSTAuth": ->
    if !@userId?
      throw new Meteor.Error 403, "You must sign in with Steam first."
    user = Meteor.users.findOne({_id: @userId})
    if !user.steamtracks?
      user.steamtracks = {authorized: false}
    if !user.steamtracks.authorized
      if !user.steamtracks.token?
        generateSTracksToken user
      else
        status = STracks.getSignupStatus user.steamtracks.token
        console.log status
        if status.status is "declined"
          generateSTracksToken user
        if status.status is "accepted"
          user.steamtracks.authorized = true
          Meteor.users.update({_id: user._id}, {$set: {steamtracks: user.steamtracks}})
          return false
      return "https://steamtracks.com/appauth/"+user.steamtracks.token
    return false
