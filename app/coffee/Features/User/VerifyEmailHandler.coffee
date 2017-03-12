Settings = require('settings-sharelatex')
redis = require("redis-sharelatex")
rclient = redis.createClient(Settings.redis.web)
crypto = require("crypto")
logger = require("logger-sharelatex")
AuthenticationManager = require("../Authentication/AuthenticationManager")

buildKey = (token)-> return "email_token:#{token}"


module.exports =

	getNewToken: (user_id, callback) ->
		if Settings.verifyEmail? and Settings.verifyEmail
			logger.log user_id:user_id, "generating token for email verification"
			token = crypto.randomBytes(32).toString("hex")
			multi = rclient.multi()
			multi.set buildKey(token), user_id
			multi.exec (err)->
				callback(err, token)
		else
			callback(null, null)

	verifyToken: (token, callback) ->
		logger.log token:token, "getting user id from email token"
		multi = rclient.multi()
		multi.get buildKey(token)
		multi.del buildKey(token)
		multi.exec (err, results)->
			if err then return callback(err)
			user_id = results[0]
			if !user_id?
				logger.err user_id:user_id, "token for email verification did not find user_id"
				return callback("no user found")
			AuthenticationManager.emailVerified user_id, callback


