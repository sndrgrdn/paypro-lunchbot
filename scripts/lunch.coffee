# Description:
#   Help keep track of whats being ordered for lunch
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Notes:
#   nom nom nom
#
# Author:
#   @sndrgrdn
#

##
# Monkeypatch unique
Array::unique = ->
  output = {}
  output[@[key]] = @[key] for key in [0...@length]
  value for key, value of output

##
# What room do you want to post the lunch messages in?
ROOM = process.env.HUBOT_LUNCHBOT_ROOM || 'general'

##
# Set to local timezone
TIMEZONE = process.env.TZ || 'Europe/Amsterdam' # default timezone

##
# Default lunch notify time
# https://www.npmjs.com/package/node-cron#cron-syntax
NOTIFY_AT = process.env.HUBOT_LUNCHBOT_NOTIFY_AT || '0 0 10 * * 3' # 10 am on Wednesday, syntax is different from normal cron

##
# clear the lunch order on a schedule
# https://www.npmjs.com/package/node-cron#cron-syntax
CLEAR_AT = process.env.HUBOT_LUNCHBOT_CLEAR_AT || '0 0 20 * * 3' # Evening on Wednesday, syntax is different from normal cron

##
# Lunchday
#
LUNCHDAY = process.env.HUBOT_LUNCHBOT_LUNCHDAY || 'Wednesday'

##
# setup cron
CronJob = require("cron").CronJob

module.exports = (robot) ->

  # Make sure the lunch dictionary exists
  robot.brain.data.lunch = robot.brain.data.lunch || {}
  robot.brain.data.orders = robot.brain.data.orders || {}

  # Explain how to use the lunch bot
  COMMANDS = """
  `i want to eat <order>` - adds food `<order>` to the lunch order
  `i want to drink <order>` - adds drinks `<order>` to the lunch order
  `remove my order` - removes your order
  `orders` - lists all orders per person
  `show order` - lists all orders per product
  `cancel orders` - cancels all orders
  `who should pickup lunch?` - randomly selects person to pickup lunch
  `help` - displays this help message
  """

  MESSAGE = """
  @channel Let's order lunch! You can say:

  #{COMMANDS}

  Menu: http://feelgoodgroningen.nl/menukaart/
  """

  ##
  # Define the lunch functions
  lunch =
    get: ->
      Object.keys(robot.brain.data.lunch)

    addFood: (user, item, type) ->
      robot.brain.data.lunch[user] = robot.brain.data.lunch[user] || {}
      robot.brain.data.lunch[user].food = item
      order.add item, user

    addDrink: (user, item, type) ->
      robot.brain.data.lunch[user] = robot.brain.data.lunch[user] || {}
      robot.brain.data.lunch[user].drink = item
      order.add item, user

    remove: (user) ->
      delete robot.brain.data.lunch[user]

    clear: ->
      robot.brain.data.lunch = {}

    notify: ->
      robot.messageRoom ROOM, MESSAGE

  ##
  # Define the order functions
  order =
    get: ->
      Object.keys(robot.brain.data.orders)

    add: (item, user) ->
      orders = robot.brain.data.orders
      orders[item] = orders[item] || []
      orders[item].push user

    clear: ->
      delete robot.brain.data.orders = {}

  ##
  # Define things to be scheduled
  schedule =
    notify: (time) ->
      new CronJob(time, ->
        lunch.notify()
        return
      , null, true, TIMEZONE)

    clear: (time) ->
      new CronJob(time, ->
        lunch.clear()
        order.clear()
        return
      , null, true, TIMEZONE)

  ##
  # Schedule when to alert the ROOM that it's time to start ordering lunch
  schedule.notify NOTIFY_AT

  ##
  # Schedule when the order should be cleared at
  schedule.clear CLEAR_AT

  ##
  # List out all the orders
  robot.respond /orders/i, (msg) ->
    orders = lunch.get().map (user) ->
      food = robot.brain.data.lunch[user].food
      drink = robot.brain.data.lunch[user].drink
      "#{user}: #{food || ''}, #{drink || ''}"
    msg.send orders.join("\n") || "No items in the lunch list."

  ##
  # List out amount of each item
  robot.respond /show order/i, (msg) ->
    orders = order.get().map (item) -> "#{item}: #{robot.brain.data.orders[item].unique().length}"
    msg.send orders.join("\n") || "No items in the lunch list."

  ##
  # Save what a person wants to the lunch order
  robot.respond /i want to eat (.*)/i, (msg) ->
    item = msg.match[1].trim()
    username = msg.message.user.name
    lunch.addFood username, item
    msg.send "OK #{username}, added #{item} to the order."

  ##
  # Save what a person wants to the lunch order
  robot.respond /i want to drink (.*)/i, (msg) ->
    item = msg.match[1].trim()
    username = msg.message.user.name
    lunch.addDrink username, item
    msg.send "OK #{username}, added #{item} to your order."

  ##
  # Remove the persons items from the lunch order
  robot.respond /remove my order/i, (msg) ->
    username = msg.message.user.name
    lunch.remove username
    msg.send "OK #{username}, I removed your order."

  ##
  # Cancel the entire order and remove all the items
  robot.respond /cancel orders/i, (msg) ->
    delete robot.brain.data.lunch
    lunch.clear()
    order.clear()
    robot.messageRoom ROOM, "lunch orders cleared..."

  ##
  # Help decided who should pickup
  robot.respond /who should pickup lunch\?/i, (msg) ->
    orders = lunch.get().map (user) -> user
    key = Math.floor(Math.random() * orders.length)

    if orders[key]?
      msg.send "@#{orders[key]} looks like you have to pickup lunch today!"
    else
      msg.send "Hmm... Looks like no one has ordered any lunch yet today."

  ##
  # Display usage details
  robot.respond /help/i, (msg) ->
    msg.send COMMANDS

  robot.respond /notify/i, (msg) ->
    lunch.notify()

  ##
  # Just print out the details on how the lunch bot is configured
  robot.respond /lunch config/i, (msg) ->
    msg.send "ROOM: #{ROOM} \nTIMEZONE: #{TIMEZONE} \nNOTIFY_AT: #{NOTIFY_AT} \nCLEAR_AT: #{CLEAR_AT}\nLUNCHDAY: #{LUNCHDAY}\n  "
