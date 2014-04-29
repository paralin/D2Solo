Template.userCard.user = ->
  Meteor.users.findOne {_id: @+""}
