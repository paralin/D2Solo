message = null
dismissMessage = ->
  return if !message?
  if message.remove?
    message.remove()
  message = null
Meteor.startup ->
  Deps.autorun ->
    status = Metrics.findOne {_id: "status"}
    dismissMessage()
    return if !status?
    message = $.pnotify
      type: "error"
      title: "Status Update"
      text: status.message
      hide: false
      nonblock: true
      buttons:
        closer: false
        sticker: false
