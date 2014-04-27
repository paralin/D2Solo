if Meteor.isServer
  Meteor.startup ->
    SeoCollection.remove({})
    stdog =
      'title': 'Dota 2 Solo Matchmaking',
      'image': 'http://d2modd.in/images/D2Logo.png'
    SeoCollection.insert
      route_name: 'home',
      title: 'Dota 2 Solo Matchmaking'
      meta:
        'description': 'One vs. one dota 2 matchmaking.'
      og: stdog
