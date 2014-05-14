@BotStatus = new Meteor.Collection "botstatus"
@BotDB = new Meteor.Collection "botdb"

Meteor.startup ->
  BotStatus.remove({})
  BotDB.remove({})
  if !process.env.NO_RUN_BOTS?
    # BotDB.insert
    #  user: "username"
    #  pass: "password"
    #  name: "[D2Solo.com] Hero"
