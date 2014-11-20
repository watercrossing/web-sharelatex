sanitize = require('sanitizer')
User = require("../../models/User").User
UserCreator = require("./UserCreator")
AuthenticationManager = require("../Authentication/AuthenticationManager")
NewsLetterManager = require("../Newsletter/NewsletterManager")
async = require("async")
EmailHandler = require("../Email/EmailHandler")
logger = require("logger-sharelatex")
Settings = require('settings-sharelatex')
VerifyEmailHandler = require('./VerifyEmailHandler')

module.exports =
	validateEmail : (email) ->
		re = /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\ ".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA -Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
		return re.test(email)
	
	isRestrictedEmail : (email) ->
		# Check if the admin has restricted email addresses, return true if ok
		if Settings.restrictSignOnEmails?
			return Settings.restrictSignOnEmails.test(email)
		else
			return true

	hasZeroLengths : (props) ->
		hasZeroLength = false
		props.forEach (prop) ->
			if prop.length == 0
				hasZeroLength = true
		return hasZeroLength

	_registrationRequestIsValid : (body, callback)->
		email = sanitize.escape(body.email).trim().toLowerCase()
		password = body.password
		username = email.match(/^[^@]*/)
		if @hasZeroLengths([password, email])
			return false
		else if !@validateEmail(email)
			return false
		else
			return true

	_createNewUserIfRequired: (user, userDetails, callback)->
		if !user?
			UserCreator.createNewUser {holdingAccount:false, email:userDetails.email}, callback
		else
			callback null, user

	registerNewUser: (userDetails, callback)->
		self = @
		requestIsValid = @_registrationRequestIsValid userDetails
		if !requestIsValid
			return callback("request is not valid")
		userDetails.email = userDetails.email?.trim()?.toLowerCase()
		User.findOne email:userDetails.email, (err, user)->
			if err?
				return callback err
			if user?.holdingAccount == false
				return callback("EmailAlreadyRegisterd")

			if not user? and not self.isRestrictedEmail userDetails.email
				return callback("RestricedEmailAddress")

			self._createNewUserIfRequired user, userDetails, (err, user)->
				if err?
					return callback(err)
				VerifyEmailHandler.getNewToken user._id, (err, token) ->
					if err?
						return callback(err)

					async.series [
						(cb)-> User.update {_id: user._id}, {"$set":{holdingAccount:false}}, cb
						(cb)-> AuthenticationManager.setUserPassword user._id, userDetails.password, cb
						(cb)-> NewsLetterManager.subscribe user, cb
						(cb)->
							if token?
								emailOpts =
									to: user.email
									verifyEmailUrl : "#{Settings.siteUrl}/register/verifyEmail?code=#{token}" 
								
								EmailHandler.sendEmail "verifyEmail", emailOpts, cb
					], (err)->
						logger.log user: user, "registered"
						callback(err, user)




