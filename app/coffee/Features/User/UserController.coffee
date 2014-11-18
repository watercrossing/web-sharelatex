UserDeleter = require("./UserDeleter")
UserLocator = require("./UserLocator")
User = require("../../models/User").User
newsLetterManager = require('../Newsletter/NewsletterManager')
UserRegistrationHandler = require("./UserRegistrationHandler")
logger = require("logger-sharelatex")
metrics = require("../../infrastructure/Metrics")
Url = require("url")
AuthenticationController = require("../Authentication/AuthenticationController")
AuthenticationManager = require("../Authentication/AuthenticationManager")
ReferalAllocator = require("../Referal/ReferalAllocator")
UserUpdater = require("./UserUpdater")
Settings = require('settings-sharelatex')

module.exports =

	deleteUser: (req, res)->
		user_id = req.session.user._id
		UserDeleter.deleteUser user_id, (err)->
			if !err?
				req.session.destroy()
			res.send(200)

	unsubscribe: (req, res)->
		UserLocator.findById req.session.user._id, (err, user)->
			newsLetterManager.unsubscribe user, ->
				res.send()

	updateUserSettings : (req, res)->
		logger.log user: req.session.user, "updating account settings"
		user_id = req.session.user._id
		User.findById user_id, (err, user)->
			if err? or !user?
				logger.err err:err, user_id:user_id, "problem updaing user settings"
				return res.send 500

			if req.body.first_name?
				user.first_name = req.body.first_name.trim()
			if req.body.last_name?
				user.last_name = req.body.last_name.trim()
			if req.body.role?
				user.role = req.body.role.trim()
			if req.body.institution?
				user.institution = req.body.institution.trim()
			if req.body.mode?
				user.ace.mode = req.body.mode
			if req.body.theme?
				user.ace.theme = req.body.theme
			if req.body.fontSize?
				user.ace.fontSize = req.body.fontSize
			if req.body.autoComplete?
				user.ace.autoComplete = req.body.autoComplete
			if req.body.spellCheckLanguage?
				user.ace.spellCheckLanguage = req.body.spellCheckLanguage
			if req.body.pdfViewer?
				user.ace.pdfViewer = req.body.pdfViewer
			user.save (err)->
				newEmail = req.body.email?.trim()
				if !newEmail? or newEmail == user.email
					return res.send 200
				else if newEmail.indexOf("@") == -1
					return res.send(400)
				else
					UserUpdater.changeEmailAddress user_id, newEmail, (err)->
						if err?
							logger.err err:err, user_id:user_id, newEmail:newEmail, "problem updaing users email address"
							if err.message == "alread_exists"
								message = req.i18n.translate("alread_exists")
							else
								message = req.i18n.translate("problem_changing_email_address")
							return res.send 500, {message:message}
						res.send(200)

	logout : (req, res)->
		metrics.inc "user.logout"
		logger.log user: req?.session?.user, "logging out"
		req.session.destroy (err)->
			if err
				logger.err err: err, 'error destorying session'
			res.redirect '/login'

	register : (req, res, next = (error) ->)->
		logger.log email: req.body.email, "attempted register"
		redir = Url.parse(req.body.redir or "/project").path
		UserRegistrationHandler.registerNewUser req.body, (err, user)->
			if err == "EmailAlreadyRegisterd"
				return AuthenticationController.login req, res
			else if err?
				next(err)
			else
				if Settings.verifyEmail? and Settings.verifyEmail
					res.send
						message:
							type: 'success'
							text: 'An email has been send to your address. Please click the verification link in that email.'
				else
					metrics.inc "user.register.success"
					req.session.user = user
					req.session.justRegistered = true
					ReferalAllocator.allocate req.session.referal_id, user._id, req.session.referal_source, req.session.referal_medium
					res.send
						redir:redir
						id:user._id.toString()
						first_name: user.first_name
						last_name: user.last_name
						email: user.email
						created: Date.now()


	changePassword : (req, res, next = (error) ->)->
		metrics.inc "user.password-change"
		oldPass = req.body.currentPassword
		AuthenticationManager.authenticate {_id:req.session.user._id}, oldPass, (err, user)->
			return next(err) if err?
			if(user)
				logger.log user: req.session.user, "changing password"
				newPassword1 = req.body.newPassword1
				newPassword2 = req.body.newPassword2
				if newPassword1 != newPassword2
					logger.log user: user, "passwords do not match"
					res.send
						message:
						  type:'error'
						  text:'Your passwords do not match'
				else
					logger.log user: user, "password changed"
					AuthenticationManager.setUserPassword user._id, newPassword1, (error) ->
						return next(error) if error?
						res.send
							message:
							  type:'success'
							  text:'Your password has been changed'
			else
				logger.log user: user, "current password wrong"
				res.send
					message:
					  type:'error'
					  text:'Your old password is wrong'

	changeEmailAddress: (req, res)->


