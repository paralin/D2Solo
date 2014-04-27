@steamidconvert = (Meteor.require "steamidconvert")()
@STracks = new SteamTracks "KBYkKGacGzZRZye7KPU6", "DBvaNuoKkWvyKX8GKmmw0VlTHvKs7wMH0X7ypKqC", true

@STracksTokens = new Meteor.Collection "strackstokens"

@toSteamID32 = (id)->
  sids = (steamidconvert.convertToText id).split ":"
  id = parseInt sids[2]
  id*(2+parseInt(sids[1]))+1

@generateSTracksToken = (user)->
  steamID32 = toSteamID32 user.services.steam.id
  token = STracks.generateSignupToken null
  user.steamtracks.token = token
  Meteor.users.update({_id: user._id}, {$set: {steamtracks: user.steamtracks}})
  console.log "Token for "+steamID32+" is "+token
  STracksTokens.insert {_id: token, user: user._id}
  token

Router.map ->
  @route "strackscb",
    where: 'server'
    path: 'streamtracks/callback'
    action: ->
      @response.writeHead 200, {'Content-Type': 'text/html'}
      token = @params.token
      if !token?
        @response.end "You need a token to complete this request."
        return
      t = STracksTokens.findOne _id:token
      if !t?
        @response.end "Invalid token."
        return
      console.log "Finalizing SteamTracks signup for "+token
      status = STracks.getSignupStatus token
      console.log status
      user = Meteor.users.findOne _id:t.user
      info = STracks.ackSignupFinish token, status.user
      console.log info
      if status.status is "declined"
        STracksTokens.remove _id: token
        @response.end "You have delined the steamtracks request."
        return
      if status.status isnt "accepted"
        @response.end "The signup process isn't finished yet (token pending still)."
        return
      STracksTokens.remove _id: token
      delete user.steamtracks['token']
      user.steamtracks.authorized = true
      user.steamtracks.info = info.userinfo
      user.steamtracks.id32 = status.user
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
        status = null
        try
          status = STracks.getSignupStatus user.steamtracks.token
          console.log status
        catch e
          status = null
        finally
          if !status? || status.status is "declined"
            generateSTracksToken user
          else if status.status is "accepted"
            user.steamtracks.authorized = true
            Meteor.users.update({_id: user._id}, {$set: {steamtracks: user.steamtracks}})
            return false
      return "https://steamtracks.com/appauth/"+user.steamtracks.token
    return false
