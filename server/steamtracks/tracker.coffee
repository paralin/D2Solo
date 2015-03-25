@steamidconvert = (Meteor.npmRequire "steamidconvert")()
@STracks = new SteamTracks "6KRhiKRF5nF3QYtcoLZW", "Jkecd05f90R17VVFpyxiClWQa9ZEDb67RwmXGFdC", false
lastCheck = 0

### Check Newbies ###
fetchInfo = (user)->
  console.log "attempting full fetch for "+user._id
  id = toSteamID32 user.services.steam.id
  res = STracks.userInfo id
  Meteor.users.update {_id: user._id}, {$set: {'steamtracks.id32': id, 'steamtracks.info': res}}
#Meteor.startup ->
  #Meteor.users.update({'steamtracks.authorized': true, 'steamtracks.id32': {$exists: false}}, {$unset: {steamtracks: ''}})
  #Meteor.users.find({'steamtracks.authorized': true, 'steamtracks.info.dota2.privateProfile': null}).observe
  #added: fetchInfo
  #changed: fetchInfo
### Track Changes ###
checkChanges = ->
  console.log "updating SteamTracks data"
  changes = null
  try
    changes = STracks.changesSince lastCheck, undefined
  catch e
    console.log "failed to fetch SteamTracks data"
    return
  lastCheck = new Date().getTime()
  for sid, ch of changes.users
    user = Meteor.users.findOne
      'steamtracks.authorized': true
      'steamtracks.id32': parseInt sid
    if !user?
      console.log "update for #{parseInt sid} but user not found"
      continue
    if ch.dota2? && ch.dota2.soloCompetitiveRank?
      ch.dota2.soloCompetitiveRank = parseInt ch.dota2.soloCompetitiveRank
    _.deepExtend user.steamtracks.info, ch
    Meteor.users.update {_id: user._id}, {$set: {steamtracks: user.steamtracks}}
    #console.log " --> #{(parseInt sid)}"
Meteor.startup ->
  checkChanges()
  Meteor.setInterval checkChanges, 60000*10

### Track Leavers ###
checkLeavers = ->
  try
    leavers = STracks.leavers()
  catch e
    console.log "failed to fetch leavers"
    return
  for leaver in leavers
    console.log leaver+" de-authed app"
    user = Meteor.users.findOne
      'steamtracks.authorized': true
      'steamtracks.id32': leaver
    continue if !user?
    user.steamtracks = {authorized: false}
    Meteor.users.update {_id: user._id}, {$set: {steamtracks: user.steamtracks}}
  STracks.flushLeavers()
Meteor.startup ->
  Meteor.setInterval checkLeavers, 15000

### Sign Up Stuff ###
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
    path: 'steamtracks/callback'
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
      @response.end "<script>window.close();</script>"
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
