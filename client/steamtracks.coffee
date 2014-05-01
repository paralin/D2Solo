Session.set "stracksURL", ""
@startSteamtracksAuth = ->
  Meteor.call "beginSTAuth", (err, res)->
    if err?
      $.pnotify
        title: "Error Authorizing SteamTracks"
        text: err.reason
        type: "error"
    else
      if !res
        #$.pnotify
        #  title: "Authorized"
        #  text: "Already authorized with SteamTracks."
        #  type: "success"
      else
        Session.set "stracksURL", res
