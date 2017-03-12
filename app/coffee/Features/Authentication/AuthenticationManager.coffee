Settings = require "settings-sharelatex"
User = require("../../models/User").User
{db, ObjectId} = require("../../infrastructure/mongojs")
crypto = require 'crypto'
bcrypt = require 'bcrypt'

BCRYPT_ROUNDS = Settings?.security?.bcryptRounds or 12

module.exports = AuthenticationManager =
	authenticate: (query, password, callback = (error, user) ->) ->
		# Using Mongoose for legacy reasons here. The returned User instance
		# gets serialized into the session and there may be subtle differences
		# between the user returned by Mongoose vs mongojs (such as default values)
		User.findOne query, (error, user) =>
			return callback(error) if error?
			if user?
				if not user.confirmed
					callback "Email not verified", null
				else if user.hashedPassword?
					bcrypt.compare password, user.hashedPassword, (error, match) ->
						return callback(error) if error?
						if match
							AuthenticationManager.checkRounds user, user.hashedPassword, password, (err) ->
								return callback(err) if err?
								callback null, user
						else
							callback null, null
				else
					callback null, null
			else
				callback null, null

	emailVerified: (user_id, callback) ->
		# Two actions to do: set confirmed: true,
		# Check if previously user.allowedToCreate, if not, check if
		# current email matches, if so, set user.allowedToCreate: true
		User.findOne _id: ObjectId(user_id.toString()), (error, user) =>
			return callback(error) if error?
			allowedToCreate = user.allowedToCreate and Settings.restrictSignOnEmails
			if not allowedToCreate
				#run regex:
				allowedToCreate = Settings.restrictSignOnEmails.test(user.email)
			db.users.update({
				_id: ObjectId(user_id.toString())
			}, {
				$set: {
					confirmed: true,
					allowedToCreate = allowedToCreate
				}
			}, callback)

	setUserPassword: (user_id, password, callback = (error) ->) ->
		if Settings.passwordStrengthOptions?.length?.max? and Settings.passwordStrengthOptions?.length?.max < password.length
			return callback("password is too long")

		bcrypt.genSalt BCRYPT_ROUNDS, (error, salt) ->
			return callback(error) if error?
			bcrypt.hash password, salt, (error, hash) ->
				return callback(error) if error?
				db.users.update({
					_id: ObjectId(user_id.toString())
				}, {
					$set: hashedPassword: hash
					$unset: password: true
				}, callback)

	checkRounds: (user, hashedPassword, password, callback = (error) ->) ->
		# check current number of rounds and rehash if necessary
		currentRounds = bcrypt.getRounds hashedPassword
		if currentRounds < BCRYPT_ROUNDS
			AuthenticationManager.setUserPassword user._id, password, callback
		else
			callback()
