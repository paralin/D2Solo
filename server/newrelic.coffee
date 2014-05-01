fs = Meteor.require "fs"

config = Assets.getText "newrelic.js"
fs.writeFileSync "newrelic.js", config

newrelic = Meteor.require "newrelic"
