Meteor.startup ->
  Meteor.subscribe("userData")
  Deps.autorun ->
    Meteor.user()
    Meteor.subscribe "lobbyDetails"
