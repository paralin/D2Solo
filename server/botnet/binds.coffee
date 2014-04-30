@randomWords = Meteor.require('random-words')
@sbinds = (b)->
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
    log "error "+e.cause
    rmeteor ->
      BotStatus.remove {_id: b.b.user}
  b.s.on 'loggedOff', ->
    log "logged off, steam went down"
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
    log "logged in"
    b.s.setPersonaState(Steam.EPersonaState.Online)
    b.s.setPersonaName b.b.name
    rmeteor ->
      BotStatus.update {_id: b.b.user}, {$set: {status: 1}}
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
    d.createPracticeLobby "D2SOLO #{lobby.user1.services.steam.username} vs. #{lobby.user2.services.steam.username}", password, undefined, Dota2.GameMode.DOTA_GAMEMODE_MO
    allowedUsers = []
    allowedUsers.push lobby.user1.services.steam.id
    allowedUsers.push lobby.user2.services.steam.id

  statusUpdate = ->
    status = BotStatus.findOne({_id: b.b.user})
    console.log status
    return if !status? || status.status < 1
    if status.status is 1
      console.log "bot #{status._id} ready"
      return
    if status.status is 2
      console.log "bot #{status._id} launching lobby #{status.lobby._id}"
      launchLobby status.lobby
    if status.status is 3
      console.log "bot #{status._id} waiting for users to connect"
      #at this point system is waiting for LobbyStartQueue status -> 3
      
  BotStatus.find({_id: b.b.user}, {limit: 1}).observe
    added: statusUpdate
    changed: statusUpdate
    removed: statusUpdate
      
  knownMembers = []
  d.on 'practiceLobbyUpdate', (resp, lobby)->
    dire = []
    radiant = []
    for member in lobby.members
      dire.push member.id if member.team is "DOTA_GC_TEAM_GOOD_GUYS"
      radiant.push member.id if member.team is "DOTA_GC_TEAM_BAD_GUYS"
      if !_.contains knownMembers, member.id
        log "#{member.name} joined lobby"
        knownMembers.push member.id
      if !_.contains allowedUsers, member.id
        log "#{member.name} not a assigned lobby member! kick him!"
    rmeteor ->
      status = BotStatus.findOne {_id: b.b.user}
      return if !status? || status.status != 3
      return if dire.length isnt 1 || radiant.length isnt 1
      for user in allowedUsers
        return if !_.contains dire, user && !_.contains radiant, user
      log "all members have joined #{status.lobby._id}"
      BotStatus.update {_id: b.b.user}, {$set: {status: 1}, $unset: {lobby: ""}}
      LobbyStartQueue.update {_id: status.lobby._id}, {$set: {status: 3}}
      d.leavePracticeLobby()
        
  d.on 'practiceLobbyCreateResponse', (resp, lobid)->
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
    d.leavePracticeLobby()
