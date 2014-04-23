Session.set("preLogin", "/")
@AuthRequired = RouteController.extend
  onBeforeAction:->
    if !Meteor.user()?
      if Router.current()?
        Session.set "preLogin", Router.current().path
      Router.go '/login'
