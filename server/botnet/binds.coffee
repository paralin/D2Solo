offlinePeriodic = null
@randomWords = Meteor.require('random-words')
@sbinds = (b)->
  onLoggedOff = ->
    BotStatus.update {_id: b.b.user}, {$set: {status: 0}}
    status = BotStatus.findOne {_id: b.b.user}
    return if !status? || !status.lobby?
    lobby = LobbyStartQueue.findOne {_id: status.lobby._id}
    return if !lobby?
    LobbyStartQueue.update {_id: lobby._id}, {$set: {status: 0}}
  log = (msg)->
    console.log "["+b.b.user+"] "+msg
  handleFriend = (sid, rel)->
    switch rel
      when Steam.EFriendRelationship.PendingInvitee
        log sid+" added us, accepting invite"
        b.s.addFriend sid
      when Steam.EFriendRelationship.None
        log sid+" removed us :("
  b.s.on 'error', (e)->
    if e.cause is "logonFail"
      rmeteor onLoggedOff
    rmeteor ->
      offlinePeriodic = Meteor.setTimeout ->
        b.s.logOn
          accountName: b.b.user
          password: b.b.pass
      , 30000
    log "error "+e.cause
    rmeteor ->
      BotStatus.remove {_id: b.b.user}
  b.s.on 'loggedOff', ->
    log "logged off, steam went down"
    if e.cause is "logonFail"
      rmeteor onLoggedOff
  b.s.on 'chatInvite', (cid, name, sid)->
    log sid+" invited us to chat "+name+ "("+cid+")"
  b.s.on 'friendMsg', (sid, msg, mtyp)->
    return if msg is ""
    log sid+": "+msg
    b.s.sendMessage sid, "Hi there, I am a bot for http://d2solo.com/. I don't know how to talk to people yet, I just set up lobbies in Dota 2."
  b.s.on 'chatStateChange', (ch, sid, cid, isid)->
    log "chat room "+cid+", "+sid+" had something done to them by "+isid
  b.s.on 'tradeProposed', (tid, sid)->
    log "rejecting trade from "+sid
    b.s.cancelTrade tid
  b.s.on 'chatMsg', (cid, msg, mtyp, sid)->
    return if msg is ""
    log sid+" ("+cid+"): "+msg
  b.s.on 'loggedOn', ->
    if offlinePeriodic?
      rmeteor ->
        Meteor.clearTimeout offlinePeriodic
      offlinePeriodic = null
    log "logged in"
    b.s.setPersonaState(Steam.EPersonaState.Online)
    b.s.setPersonaName b.b.name
    rmeteor ->
      BotStatus.update {_id: b.b.user}, {$set: {status: 1, sid: b.s.steamID}}
  b.s.on 'relationships', ->
    for sid, friend of b.s.friends
      handleFriend sid, friend
  b.s.on 'friend', (sid, friend)->
    handleFriend sid, friend

@dbinds = (b)->
  password = ""
  allowedUsers = []
  log = (msg)->
    console.log "["+b.b.user+"][Dota] "+msg
  d = b.d

  launchLobby = (lobby)->
    password = randomWords({exactly: 2, join: ' '})
    d.leavePracticeLobby()
    lobby.user1.queue.region = undefined if lobby.user1.queue.region is "all"
    lobby.user2.queue.region = undefined if lobby.user2.queue.region is "all"
    region = lobby.user1.queue.region || lobby.user2.queue.region || undefined
    console.log "Launching lobby #{lobby._id}, region #{region}"
    if region?
      switch region
        when "na" then region = Dota2.ServerRegion.USWEST
        when "eu" then region = Dota2.ServerRegion.EUROPE
        when "aus" then region = Dota2.ServerRegion.AUSTRALIA
    d.createPracticeLobby "D2SOLO #{lobby.user1.services.steam.username} vs. #{lobby.user2.services.steam.username}", password, region, Dota2.GameMode.DOTA_GAMEMODE_MO
    allowedUsers = []
    allowedUsers.push lobby.user1.services.steam.id
    allowedUsers.push lobby.user2.services.steam.id
  waitInterval = null
  statusUpdate = ->
    status = BotStatus.findOne({_id: b.b.user})
    return if !status? || status.status < 1
    if status.status is 0
      log "Bot offline."
    if status.status is 1
      log "Ready to create lobbies"
      return
    if status.status is 2
      log "Starting lobby #{status.lobby._id}"
      launchLobby status.lobby
    if status.status is 3
      log "Waiting for users to connect..."
      waitInterval = Meteor.setTimeout ->
        status = BotStatus.findOne {_id: b.b.user}
        return if !status? || status.status isnt 3 || !status.lobby?
        lobby = LobbyStartQueue.findOne {_id: status.lobby._id}
        return if !lobby?
        log "lobby #{lobby._id} timed out"
        d.leavePracticeLobby()
        BotStatus.update {_id: b.b.user}, {$unset: {lobby: ""}, $set: {status: 1}}
        LobbyStartQueue.update {_id: lobby._id}, {$set: {status: 99}}
      , 120000
    else
      if waitInterval?
        Meteor.clearTimeout waitInterval
        waitInterval = null
  BotStatus.find({_id: b.b.user}, {limit: 1}).observe
    added: statusUpdate
    changed: statusUpdate
    removed: statusUpdate
      
  knownMembers = []
  d.on 'practiceLobbyUpdate', (resp, lobby)->
    dire = []
    radiant = []
    for member in lobby.members
      if member.team is "DOTA_GC_TEAM_GOOD_GUYS"
        radiant.push member.id
      else if member.team is "DOTA_GC_TEAM_BAD_GUYS"
        dire.push member.id
      if !_.contains knownMembers, member.id
        log "#{member.name} joined lobby"
        knownMembers.push member.id
      if member.id != b.s.steamID and !_.contains allowedUsers, member.id
        log "#{member.name} not an assigned lobby member! kick him!"
    rmeteor ->
      status = BotStatus.findOne {_id: b.b.user}
      return if !status? || status.status != 3
      return if dire.length isnt 1 || radiant.length isnt 1
      for user in allowedUsers
        direHas = _.contains dire, user
        radiantHas = _.contains radiant, user
        return if !direHas && !radiantHas
      log "all members have joined #{status.lobby._id}"
      BotStatus.update {_id: b.b.user}, {$set: {status: 1}, $unset: {lobby: ""}}
      LobbyStartQueue.update {_id: status.lobby._id}, {$set: {status: 3}}
      d.leavePracticeLobby()
        
  d.on 'practiceLobbyCreateResponse', (resp, lobid)->
    knownMembers = []
    rmeteor ->
      status = BotStatus.findOne {_id: b.b.user}
      return if !status? || status.status < 2
      if status.status is 2
        log "lobby created, lobid #{lobid} for lobby id #{status.lobby._id}"
        BotStatus.update {_id: b.b.user}, {$set: {status: 3}}
        LobbyStartQueue.update {_id: status.lobby._id}, {$set: {status: 1, pass: password}}
  b.s.on 'loggedOn', ->
    d.launch()
  b.fetchMatchResult = (id)->
    return if !id?
    res = Async.runSync (done)->
      existing = MatchResults.findOne {_id: id}
      if existing?
        return done(null, existing)
      d.matchDetailsRequest id, (f, data)->
        if data.result != 1
          log "Failed to fetch match."
          done null, null
        console.log data.match
        match = data.match
        match._id = id
        delete match["matchId"]
        rmeteor ->
          MatchResults.insert match
        done null, match
    return res.result
  d.on 'ready', ->
    log "Dota client ready."
    rmeteor ->
      bots = BotStatus.find({sid: {$exists: true}}).fetch()
      for bot in bots
        b.s.addFriend bot.sid
    d.leavePracticeLobby()
