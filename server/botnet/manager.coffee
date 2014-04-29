@Steam = Meteor.require "steam"
@Dota2 = Meteor.require "dota2"
@Fiber = Meteor.require "fibers"

@AccountID = (steamID)->
  Dota2.Dota2Client::ToAccountID(steamID)

@rmeteor = (fcn)->
  new Fiber(fcn).run()

clients = {}

startLobby = ->
  lobby = LobbyStartQueue.findOne {status: 0}
  bot = BotStatus.findOne {status: 1}
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
  dclient = new Dota2.Dota2Client sclient, true
  clients[bot.user] =
    s: sclient
    d: dclient
    b: bot
  sclient.logOn
    accountName: bot.user
    password: bot.pass
  sbinds clients[bot.user]
  dbinds clients[bot.user]

Meteor.startup ->
  Deps.autorun startLobby
  BotDB.find().observe
    added: startBot
    changed: updateBot
    removed: shutdownBot
