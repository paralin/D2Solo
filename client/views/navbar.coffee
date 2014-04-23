Template.navbar.helpers
  ar: (path)->
    route = Router.current()
    if !route?
      return
    return "navActiveB" if(route.route.name == path)
Template.navbar.isAdmin = ->
  AuthManager.userIsInRole(Meteor.userId(), "admin")
