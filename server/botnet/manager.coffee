@Steam = Meteor.require "steam"
@Dota2 = Meteor.require "dota2"
@Fiber = Meteor.require "fibers"

@AccountID = (steamID)->
  Dota2.Dota2Client::ToAccountID(steamID)

@rmeteor = (fcn)->
  new Fiber(fcn).run()

clients = {}

startLobby = (lobby, bot)->
  lobby = LobbyStartQueue.findOne {status: 0} if !lobby?
  bot = BotStatus.findOne {status: 1} if !bot?
  return if !lobby? || !bot?
  console.log "assigning bot #{bot._id} to #{lobby._id}"
  BotStatus.update {_id: bot._id}, {$set: {status: 2, lobby: lobby}}

shutdownBot = (bot)->
  stat = BotStatus.findOne {_id: bot.user}
  return if !stat?
  console.log "shutting down bot "+bot.user
  c = clients[bot.user]
  return if !c?
  c.s.logOff()
  delete clients[bot.user]
  BotStatus.remove {_id: bot.user}

updateBot = (bot)->
  stat = BotStatus.findOne {_id: bot.user}
  return if !stat?
  return if stat.status < 1
  c = clients[bot.user]
  return if !c?
  c.s.setPersonaName bot.name

startBot = (bot)->
  stat = BotStatus.findOne {_id: bot.user}
  return if stat?
  console.log "starting bot "+bot.user
  BotStatus.insert
    _id: bot.user
    status: 0
  sclient = new Steam.SteamClient
  dclient = new Dota2.Dota2Client sclient, false
  clients[bot.user] =
    s: sclient
    d: dclient
    b: bot
  sclient.logOn
    accountName: bot.user
    password: bot.pass
  sbinds clients[bot.user]
  dbinds clients[bot.user]

botCount = 0
updateStatusMsg = ->
  msg = Metrics.findOne {_id: "status"}
  if botCount is 0 && !msg?
    Metrics.insert {_id: "status", message: "All bots are offline. Steam might be down.", auto: true}
  else if msg? && botCount > 0 && msg.auto
    Metrics.remove {_id: "status"}
Meteor.startup ->
  LobbyStartQueue.find({status: 0}).observe
    added: startLobby
  BotStatus.find({status: 1}).observe
    added: (b)->
      startLobby undefined, b
  BotDB.find().observe
    added: startBot
    changed: updateBot
    removed: shutdownBot
  BotStatus.find({status: {$gt: 0}}).observeChanges
    added: ->
      botCount++
      updateStatusMsg()
    removed: ->
      botCount--
      updateStatusMsg()
  updateStatusMsg()
