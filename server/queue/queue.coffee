mmrField = 'steamtracks.info.dota2.soloCompetitiveRank'

queueProc = ->
  baseQuery = {'queue.matchFound': false}
  queuing = Meteor.users.find(baseQuery, {fields: {queue: 1, steamtracks: 1}}).fetch()
  mfound = []
  for user in queuing
    continue if _.contains mfound, user._id
    mmr = parseInt user.steamtracks.info.dota2.soloCompetitiveRank
    mmrmax = mmr+user.queue.range
    mmrmin = mmr-user.queue.range
    #console.log "range #{user.queue.range} mmr #{mmr} max #{mmrmax}"
    query = {$and: []}
    minq = {}
    minq[mmrField] = {$gt: mmrmin}
    maxq = {}
    maxq[mmrField] = {$lt: mmrmax}
    query['$and'].push(minq)
    query['$and'].push(maxq)
    query._id = {$ne: user._id}
    _.extend query, baseQuery
    match = Meteor.users.findOne query
    if match?
      console.log "match found for #{user._id} (#{mmr}) and #{match._id}(#{match.steamtracks.info.dota2.soloCompetitiveRank})"
      mfound.push match._id
      Meteor.users.update {_id: user._id}, {$set: {'queue.matchFound': true, 'queue.matchUser': match._id, 'queue.hasAccepted': false}}
      Meteor.users.update {_id: match._id}, {$set: {'queue.matchFound': true, 'queue.matchUser': user._id, 'queue.hasAccepted': false}}
doIncRange = ->
  Meteor.users.update {'queue.range': {$lt: 9000}, 'queue': {$exists: true}, 'queue.matchFound': false, 'status.online': true}, {$inc: {'queue.range': 50}}, {multi: true}
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
Meteor.startup ->
  LobbyStartQueue.remove({})
  Meteor.users.update {}, {$set: {queue: null}}, {multi: true}
  Meteor.setInterval doIncRange, 1000
  queueCount = 0
  LobbyStartQueue.find({status:3}).observe
    added: (lobby)->
      console.log "lobby #{lobby._id} has begun play"
      LobbyStartQueue.remove {_id: lobby._id}
      Meteor.users.update {'queue.lobbyID': lobby._id}, {$set: {'queue.hasStarted': true}}, {multi: true}
  LobbyStartQueue.find({status: 1}).observe
    added: (lobby)->
      Meteor.users.update {'queue.lobbyID': lobby._id}, {$set: {'queue.lobbyPass': lobby.pass}}, {multi: true}
      LobbyStartQueue.update {_id: lobby._id}, {$set: {status: 2}}
      console.log "lobby launched, password #{lobby.pass}"
  Meteor.users.find({'queue.matchFound': true, 'queue.lobbyPass': 'loading'}).observe
    added: (user)->
      console.log "#{user._id} loading lobby #{user.queue.lobbyID}"
      startLobby user._id, user.queue
  Meteor.users.find({'queue.matchFound': true, 'queue.hasStarted': {$exists: false}, 'queue.lobbyPass': {$exists: false}}).observe
    added: (user)->
      console.log "#{user._id} entered waiting to accept state"
      acceptTimeouts[user._id] = Meteor.setTimeout ->
        delete acceptTimeouts[user._id]
        Meteor.users.update {_id: user._id}, {$set: {queue: null, 'queueP': {preventUntil: new Date().getTime()+30000}}}
        if user.queue.matchUser isnt user._id
          Meteor.users.update {_id: user.queue.matchUser}, {$set: {queue: {range: 300, matchFound: false}}}
      , 10000
    changed: (user)->
      match = Meteor.users.findOne _id:user.queue.matchUser
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
      console.log "#{user._id} no longer in decision state"
      if acceptTimeouts[user._id]?
        Meteor.clearTimeout acceptTimeouts[user._id]
        delete acceptTimeouts[user._id]
  Meteor.users.find({'queue.matchFound': false, 'status.online': true}, {fields: {queue: 1, status: 1, steamtracks: 1}}).observe
    added: (user)->
      Metrics.update {_id: "queue"}, {$inc: {count: 1}}
      console.log "new user "+user._id+" queueing"
      queueCount++
    removed: (user)->
      queueCount--
      Metrics.update {_id: "queue"}, {$inc: {count: -1}}
      console.log "user stopped queueing "+user._id
      #Meteor.users.update {_id: user._id}, {$set: {queue: null}}
  Meteor.setInterval queueProc, 2000

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
    Meteor.users.update {_id: @userId}, {$set: {queue: null, 'queueP': {preventUntil: new Date().getTime()+30000}}}
    if user.queue.matchUser isnt user._id
      Meteor.users.update {_id: user.queue.matchUser}, {$set: {queue: {range: 300, matchFound: false}}}
  "stopQueue": ->
    return if !@userId?
    user = Meteor.users.findOne _id:@userId
    return if !user.queue?
    Meteor.users.update {_id: @userId}, {$set: {queue: null}}
  "startQueuing": ->
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
    if !user.steamtracks.info.dota2.soloCompetitiveRank?
      throw new Meteor.Error 403, "You have not finished your calibration games for solo MMR yet."
    if user.queueP?
      if user.queueP.preventUntil > new Date().getTime()
        throw new Meteor.Error 403, "You are prevented from matchmaking for 30 seconds."
      else
        Meteor.users.update {_id:user._id}, {$unset: {queueP: ''}}
    Meteor.users.update({_id: @userId}, {$set: {queue: {matchFound: false, range: 50}}})
