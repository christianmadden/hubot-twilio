
# TODO How to delay sending SMS so they don't arrive out of order?

{ Robot, Adapter, TextMessage, User } = require 'hubot'
QS = require "querystring"

class Twilio extends Adapter

  constructor: (robot) ->
    @robot = robot

  run: ->

    options =
      sid: process.env.HUBOT_SMS_SID
      token: process.env.HUBOT_SMS_TOKEN
      from: process.env.HUBOT_SMS_FROM
      name: process.env.HUBOT_NAME

    return @robot.logger.error "No Twilio SID provided to Hubot" unless options.sid
    return @robot.logger.error "No Twilio token provided to Hubot" unless options.token
    return @robot.logger.error "No Twilio from number provided to Hubot" unless options.from
    return @robot.logger.error "No bot name provided to Hubot" unless options.name

    @options = options

    @robot.logger.info "Running Twilio adapter for bot: #{@options.name}"
    @emit "connected"

    # Listen for webhook requests for incoming messages
    @robot.router.get "/hubot/sms", (request, response) =>
      payload = QS.parse(request.url)
      if payload.Body? and payload.From?
        @robot.logger.info "Received SMS to #{@options.name}: #{payload.Body} from #{payload.From}"
        @receive_sms(payload.Body, payload.From)
      response.writeHead 200, 'Content-Type': 'text/plain'
      response.end()

  # Take incoming messages and hand them off to the bot
  receive_sms: (body, from) ->
    return if body.length is 0
    user = new User from
    message = new TextMessage user, "@#{@options.name}: #{body}"
    @robot.receive message

  # Bot has requested an outbound message to be sent
  send: (envelope, strings...) ->
    full_message = strings.join "\n"
    console.log "Sending reply SMS from #{@options.name}: #{full_message} to #{envelope.user.id}"
    messages = split_string(full_message, 150)
    for message in messages
      # Stagger the messages by a second so they (hopefully) arrive in order
      setTimeout ->
        @send_sms message, envelope.user.id, (err, body) ->
          if err or not body?
            console.log "Error sending reply SMS: #{err}"
          else
            console.log "Sending reply SMS: #{message} to #{envelope.user.id}"
      , 1000

  # Because SMS doesn't have multiple users like chat, a reply is the same as a send
  reply: (envelope, strings...) -> @send envelope, strings...

  send_sms: (message, to, callback) ->
    auth = new Buffer(@options.sid + ':' + @options.token).toString("base64")
    data = QS.stringify From: @options.from, To: to, Body: message
    @robot.http("https://api.twilio.com")
      .path("/2010-04-01/Accounts/#{@options.sid}/SMS/Messages.json")
      .header("Authorization", "Basic #{auth}")
      .header("Content-Type", "application/x-www-form-urlencoded")
      .post(data) (err, res, body) ->
        if err
          callback err
        else if res.statusCode is 201
          callback null, body
        else
          callback body.message

  split_string: (string, length) ->
    strings = []
    while(string.length > length)
        var pos = string.substring(0, length).lastIndexOf(' ')
        pos = pos <= 0 ? length : pos
        strings.push(string.substring(0, pos))
        var i = string.indexOf(' ', pos) + 1
        if(i < pos || i > pos + length)
            i = pos
        string = string.substring(i)
    }
    strings.push(string)
    return strings
}

exports.use = (robot) ->
  new Twilio robot
