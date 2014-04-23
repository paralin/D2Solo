Router.map ->
  @route 'bottest',
    path: '/bottest'
    controller: AuthRequired
    before: ->
      @redirect '/' if (!AuthManager.userIsInRole(Meteor.userId(), "admin"))
    template: 'bottest'
