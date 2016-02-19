
{Robot, Adapter, TextMessage, User} = require 'hubot'

QS = require "querystring"

class Twilio extends Adapter

  constructor: (robot) ->
    @robot = robot
    @sid   = process.env.HUBOT_SMS_SID
    @token = process.env.HUBOT_SMS_TOKEN
    @from  = process.env.HUBOT_SMS_FROM

  run: ->

    options =
      sid: process.env.HUBOT_SMS_SID
      token: process.env.HUBOT_SMS_TOKEN
      from: process.env.HUBOT_SMS_FROM

    return @robot.logger.error "No Twilio SID provided to Hubot" unless options.sid
    return @robot.logger.error "No Twilio token provided to Hubot" unless options.token
    return @robot.logger.error "No Twilio from number provided to Hubot" unless options.from

    @options = options

    @robot.logger.info "Run"
    @emit "connected"

    @robot.router.get "/hubot/sms", (request, response) =>
      payload = QS.parse(request.url)

      if payload.Body? and payload.From?
        @robot.logger.info "Received SMS: #{payload.Body} from #{payload.From}"
        @receive_sms(payload.Body, payload.From)

      response.writeHead 200, 'Content-Type': 'text/plain'
      response.end()

  send: (envelope, strings...) ->
    message = strings.join "\n"
    message_chunks = @chunk_for_sms message
    for chunk in message_chunks
      @send_sms chunk, envelope.user.id, (err, body) ->
        if err or not body?
          console.log "Error sending reply SMS: #{err}"
        else
          console.log "Sending reply SMS: #{message} to #{envelope.user.id}"

  reply: (envelope, strings...) ->
    @send envelope, str for str in strings

  receive_sms: (body, from) ->
    return if body.length is 0
    user = new User from
    message = new TextMessage user, body
    @robot.receive message

  chunk_for_sms: (message) ->
    message.match(/^(\r\n|.){1,160}\b/g).join('')

  send_sms: (message, to, callback) ->
    auth = new Buffer(@options.sid + ':' + @options.token).toString("base64")
    data = QS.stringify From: @options.from, To: to, Body: message

    @robot.http("https://api.twilio.com")
      .path("/2010-04-01/Accounts/#{@options.sid}/SMS/Messages.json")
      .header("Authorization", "Basic #{auth}")
      .header("Content-Type", "application/x-www-form-urlencoded")
      .post(data) (err, res, body) ->
        console.log(err)
        console.log(body)
        if err
          callback err
        else if res.statusCode is 201
          callback null, body
        else
          callback body.message

exports.use = (robot) ->
  new Twilio robot
