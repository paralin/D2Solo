Meteor.setInterval ->
  Session.set("500mstick", new Date().getTime())
, 500
