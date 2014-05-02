##Metrics
#
# _id: "queue"
# count: How many users are currently queuing
#
# _id: "stats"
# lobbyCount: number of lobbies ever created successfully
#
# _id: "status"
# text: status text
#
# _id: "users"
# count: user count
@Metrics = new Meteor.Collection "metrics"
