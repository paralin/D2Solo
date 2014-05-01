if Meteor.isServer
  Meteor.startup ->
    SeoCollection.remove({})
    stdog =
      'title': 'Dota 2 Solo Matchmaking',
      'image': 'http://d2modd.in/images/D2Logo.png'
    SeoCollection.insert
      route_name: 'home',
      title: 'D2 Solo Matchmaking'
      meta:
        'description': 'One vs. one Dota 2 matchmaking.'
      og: stdog
    SeoCollection.insert
      route_name: 'leaderboards',
      title: '1v1 Leaderboards'
      meta:
        'description': '1v1 matchmaking leaderboards.'
      og: stdog
    SeoCollection.insert
      route_name: 'matchmaking'
      title: 'Find a Match'
      meta:
        'description': '1v1 matchmaking search.'
      og: stdog
