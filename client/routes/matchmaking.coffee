Meteor.startup ->
  Deps.autorun ->
    route = Router.current()
    return if !route?
    user = Meteor.user()
    return if !user? || !user.queue? || !user.queue.matchFound?
    if route.route.name isnt "matchmaking"
      Router.go(Router.routes["matchmaking"].path())
      $.pnotify
        title: "Matchmaking"
        text: "You are currently matchmaking."
        type: "error"

Router.map ->
  @route "matchmaking",
    path: "/mm"
    template: "matchmaking"
