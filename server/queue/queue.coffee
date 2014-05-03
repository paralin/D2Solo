mmrField = 'steamtracks.info.dota2.soloCompetitiveRank'

queueProc = ->
  baseQuery = {'queue.matchFound': false, 'status.online': true}
  queuing = Meteor.users.find(baseQuery, {fields: {queue: 1, steamtracks: 1}}).fetch()
  for user in queuing
    mmr = parseInt user.steamtracks.info.dota2.soloCompetitiveRank
    mmrmax = mmr+user.queue.range
    mmrmin = mmr-user.queue.range
    query = {$and: []}
    minq = {}
    minq[mmrField] = {$gt: mmrmin}
    maxq = {}
    maxq[mmrField] = {$lt: mmrmax}
    query['$and'].push(minq)
    query['$and'].push(maxq)
    query._id = {$ne: user._id}
    if user.queue.region? && user.queue.region isnt "all"
      query["queue.region"] = user.queue.region
    _.extend query, baseQuery
    match = Meteor.users.findOne query
    if match?
      console.log "match found for #{user._id} (#{mmr}) and #{match._id}(#{match.steamtracks.info.dota2.soloCompetitiveRank})"
      Meteor.users.update {_id: user._id}, {$set: {'queue.matchFound': true, 'queue.matchUser': match._id, 'queue.hasAccepted': false}}
      Meteor.users.update {_id: match._id}, {$set: {'queue.matchFound': true, 'queue.matchUser': user._id, 'queue.hasAccepted': false}}
      return
doIncRange = ->
  Meteor.users.update {'queue.range': {$lt: 3000}, 'queue': {$exists: true}, 'queue.matchFound': false, 'status.online': true}, {$inc: {'queue.range': 25}}, {multi: true}
@LobbyStartQueue = new Meteor.Collection "lobbyStartQueue"
startLobby = (uid, queue)->
  stats = LobbyStartQueue.findOne {_id: queue.lobbyID}
  if !stats?
    stats =
      status: 0
      bot: null
      pass: ""
      user1: Meteor.users.findOne({_id: uid})
      user2: Meteor.users.findOne({_id: queue.matchUser})
      _id: queue.lobbyID
    LobbyStartQueue.insert stats

acceptTimeouts = {}
userRegions = {}
lobbyStartTimeouts = {}
Meteor.startup ->
  LobbyStartQueue.remove({})
  Meteor.users.update {}, {$set: {queue: null}}, {multi: true}
  Meteor.setInterval doIncRange, 1000
  LobbyStartQueue.find({status: 99}).observe
    added: (lobby)->
      console.log "lobby #{lobby._id} timed out"
      LobbyStartQueue.remove {_id: lobby._id}
      Meteor.users.update {_id: lobby.user1._id}, {$set: {queue: {matchFound: false, range: 300, region: lobby.user1.queue.region}}}
      Meteor.users.update {_id: lobby.user2._id}, {$set: {queue: {matchFound: false, range: 300, region: lobby.user2.queue.region}}}
  LobbyStartQueue.find({status:3}).observe
    added: (lobby)->
      console.log "lobby #{lobby._id} has begun play"
      LobbyStartQueue.remove {_id: lobby._id}
      Meteor.users.update {'queue.lobbyID': lobby._id}, {$set: {'queue.hasStarted': true}}, {multi: true}
      incLobbyCount()
  LobbyStartQueue.find({status: 1}).observe
    added: (lobby)->
      Meteor.users.update {'queue.lobbyID': lobby._id}, {$set: {'queue.lobbyPass': lobby.pass}}, {multi: true}
      LobbyStartQueue.update {_id: lobby._id}, {$set: {status: 2}}
      console.log "lobby launched, password #{lobby.pass}"
  Meteor.users.find({'queue.matchFound': true, 'queue.lobbyPass': 'loading'}).observe
    added: (user)->
      #console.log "#{user._id} loading lobby #{user.queue.lobbyID}"
      startLobby user._id, user.queue
  Meteor.users.find({'queue.matchFound': true, 'queue.hasStarted': {$exists: false}, 'queue.lobbyPass': {$exists: false}}).observe
    added: (user)->
      console.log "#{user._id} entered waiting to accept state"
      acceptTimeouts[user._id] = Meteor.setTimeout ->
        delete acceptTimeouts[user._id]
        user = Meteor.users.findOne({_id: user._id})
        return if user.queue.hasAccepted
        Meteor.users.update {_id: user._id}, {$unset: {queue: ''}, $set: {'queueP': {preventUntil: new Date().getTime()+30000}}}
        if user.queue.matchUser isnt user._id
          match = Meteor.users.findOne({_id: user.queue.matchUser})
          Meteor.users.update {_id: user.queue.matchUser}, {$set: {queue: {range: 300, matchFound: false, region: match.queue.region}}}
      , 20000
    changed: (user)->
      match = Meteor.users.findOne _id:user.queue.matchUser
      return if !user.queue? || !match.queue?
      if user.queue.hasAccepted && !match.queue.lobbyPass?
        console.log "#{user._id} accepted match with #{user.queue.matchUser}"
        if acceptTimeouts[user._id]?
          Meteor.clearTimeout acceptTimeouts[user._id]
          delete acceptTimeouts[user._id]
        if match.queue.hasAccepted
          upd = {'queue.lobbyPass': 'loading', 'queue.lobbyID': Random.id()}
          Meteor.users.update {_id:user._id}, {$set: upd}
          Meteor.users.update {_id:user.queue.matchUser}, {$set: upd}
    removed: (user)->
      if acceptTimeouts[user._id]?
        Meteor.clearTimeout acceptTimeouts[user._id]
        delete acceptTimeouts[user._id]
  Meteor.users.find({'queue.matchFound': false, 'status.online': true}, {fields: {queue: 1, status: 1, steamtracks: 1}}).observe
    added: (user)->
      upd = {count:1}
      upd[user.queue.region] = 1
      Metrics.update {_id: "queue"}, {$inc: upd}
      userRegions[user._id] = user.queue.region
      console.log "Start queue: "+user._id+" Region: "+user.queue.region
    removed: (user)->
      upd = {count: -1}
      region = userRegions[user._id]
      if region?
        upd[region] = -1
      Metrics.update {_id: "queue"}, {$inc:upd}
      console.log "Exit queue pool: "+user._id
  Meteor.setInterval queueProc, 1000

Meteor.methods
  "closeMatch": ->
    if !@userId?
      throw new Meteor.Error 403, "You are not logged in."
    user = Meteor.users.findOne _id:@userId
    if !user.queue?
      throw new Meteor.Error 404, "You are not in a game."
    if !user.queue.matchFound
      throw new Meteor.Error 404, "Match has not been found."
    if !user.queue.hasStarted
      throw new Meteor.Error 404, "Match has not started yet."
    Meteor.users.update {_id:@userId}, {$unset: {queue: ""}}
  "acceptMatch": ->
    if !@userId?
      throw new Meteor.Error 403, "You are not logged in."
    user = Meteor.users.findOne _id:@userId
    if !user.queue?
      throw new Meteor.Error 404, "You are not waiting to accept."
    if !user.queue.matchFound
      throw new Meteor.Error 404, "Match has not been found."
    user.queue.hasAccepted = true
    Meteor.users.update {_id: user._id}, {$set: {queue: user.queue}}
  "declineMatch": ->
    if !@userId?
      throw new Meteor.Error 403, "You are not logged in."
    user = Meteor.users.findOne _id:@userId
    if !user.queue?
      throw new Meteor.Error 404, "You are not waiting to accept."
    if !user.queue.matchFound
      throw new Meteor.Error 404, "Match has not been found."
    Meteor.users.update {_id: @userId}, {$unset: {'queue': ''}, $set: {'queueP': {preventUntil: new Date().getTime()+30000}}}
    if user.queue.matchUser isnt user._id
      match = Meteor.users.findOne({_id: user.queue.matchUser})
      Meteor.users.update {_id: match._id}, {$set: {queue: {range: 300, matchFound: false, region: match.queue.region}}}
  "stopQueue": ->
    return if !@userId?
    user = Meteor.users.findOne _id:@userId
    return if !user.queue?
    Meteor.users.update {_id: @userId}, {$unset: {queue: ''}}
  "startQueuing": (region)->
    if !region? || !Regions[region]?
      region = "all"
    if !@userId?
      throw new Meteor.Error 403, "You must be logged into start queueing."
    user = Meteor.users.findOne _id: @userId
    if user.queue?
      if user.matchFound
        throw new Meteor.Error 403, "You have already found a match."
      else
        throw new Meteor.Error 403, "You are already queueing."
    if !user.steamtracks.authorized
      throw new Meteor.Error 402, "You must be linked to SteamTracks."
    if !user.steamtracks.info?
      throw new Meteor.Error 403, "We don't have your SteamTracks info yet. Please wait a little while."
    if !user.steamtracks.info.dota2.privateProfile?
      if !user.steamtracks.info.dota2.soloCompetitiveRank?
        console.log "user #{@userId} has null data, filling in 3k mmr"
        Meteor.users.update {_id: @userId}, {$set: {'steamtracks.info.dota2.soloCompetitiveRank': 3000}}
    else if user.steamtracks.info.dota2.privateProfile is '1'
      throw new Meteor.Error 403, "Your profile is private, please make it public (in Dota2)."
    else if !user.steamtracks.info.dota2.soloCompetitiveRank?
      throw new Meteor.Error 403, "You have not finished your calibration games for solo MMR yet."
    if user.queueP?
      if user.queueP.preventUntil > new Date().getTime()
        throw new Meteor.Error 403, "You are prevented from matchmaking for 30 seconds."
      else
        Meteor.users.update {_id:user._id}, {$unset: {queueP: ''}}
    Meteor.users.update({_id: @userId}, {$set: {queue: {matchFound: false, range: 50, region: region}}})
