Template.matchmaking.preventTime = ->
  user = Meteor.user()
  return if !user?
  moment(user.queueP.preventUntil).format "h:mm:ss a"
Template.matchmaking.events
  "click .closeMatch": ->
    Meteor.call "closeMatch", (err, res)->
      if err?
        $.pnotify
          title: "Can't Close"
          text: err.reason
          type: "error"
  "click .acceptMatch": ->
    Meteor.call "acceptMatch", (err, res)->
      if err?
        $.pnotify
          title: "Can't Accept"
          text: err.reason
          type: "error"
  "click .rejectMatch": ->
    Meteor.call "declineMatch", (err, res)->
      if err?
        $.pnotify
          title: "Can't Decline"
          text: err.reason
          type: "error"
  "click .stopQueue": ->
    Meteor.call "stopQueue"
  "click #startQueuing": ->
    Meteor.call "startQueuing", (err,res)->
      if err?
        if err.error is 402
          startSteamtracksAuth()
          $.pnotify
            title: "SteamTracks Auth"
            text: "Please complete the pop-up steamtracks authorization."
            type: "info"
        else
          $.pnotify
            title: "Can't Queue"
            type: "error"
            text: err.reason
  "click #startSTracksAuth": ->
    $("#startSTrackAuth").prop('disabled', true)

Template.matchmaking.steamTracks = ->
  startSteamtracksAuth()
  Session.get "stracksURL"

targetFindTime = 30000
Meteor.startup ->
  Session.set "findProgress", 50
  Session.set "findStartTime", 0
  Deps.autorun ->
    user = Meteor.user()
    curr = Session.get "findProgress"
    startTime = Session.get "findStartTime"
    currTime = Session.get "500mstick"
    Session.set "servTimeElapsed", Math.floor((currTime-startTime)/1000)
    if !user? || !user.queue?
      Session.set "findProgress", 0
      Session.set "findStartTime", 0
    else if user.queue?
      if !user.queue.matchFound
        if Session.get("findStartTime") is 0
          Session.set "findStartTime", new Date().getTime()
        prog = (currTime-startTime)/targetFindTime*100
        if prog > 90
          targetFindTime *= 2
        Session.set "findProgress", prog
        Session.set "servProgColor", "info"
      else
        Session.set "findProgress", 100
        Session.set "servProgColor", "success"
Template.matchmaking.servProgColor = ->
  Session.get "servProgColor"
Template.matchmaking.progBarClass = ->
  user = Meteor.user()
  return "progress-striped active" if user? && user.queue? && !user.queue.matchFound
  "collapsed"
Template.matchmaking.dialogClass = ->
  user = Meteor.user()
  if user? && user.queue?
    if user.queue.matchFound
      return "findDialogLarger"
Template.matchmaking.progress = ->
  Session.get "findProgress"
Template.matchmaking.lobbyPass = ->
  user = Meteor.user()
  return if !user? || !user.queue? || !user.queue.lobbyPass? || user.queue.lobbyPass is "loading"
  user.queue.lobbyPass
  
Template.matchmaking.status = ->
  user = Meteor.user()
  if user? && user.queue?
    if user.queue.matchFound
      if user.queue.lobbyPass? and user.queue.lobbyPass isnt "loading"
        return "Lobby ready, connect now!"
      return "Found a match!"
    else
      return "Searching for a match..."
  "I'm confused, what's going on?"
Template.matchmaking.searchRange = ->
  user = Meteor.user()
  return if !user.queue?
  user.queue.range
Template.matchmaking.queueCount = ->
  info = Metrics.findOne(_id: "queue")
  info.count
