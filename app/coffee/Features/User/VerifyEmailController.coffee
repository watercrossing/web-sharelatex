VerifyEmailHandler = require("./VerifyEmailHandler")
logger = require("logger-sharelatex")
Url = require("url")

module.exports =
	receiveVerification : (req, res) ->	
		# An 'email verification' link has been clicked.
		logger.log query:req.query, "email verification page called"
		if !req.query?.code?
			return ErrorController.notFound(req, res)
		code = req.query.code
		logger.log "Received verification code #{code}"
		if !code? or code.length == 0
			return ErrorController.notFound(req, res)
		VerifyEmailHandler.verifyToken code.trim(), (err) ->
			if err?
				res.send message:
					text: "Verification token is incorrect."
					type: "error"
			else
				res.render 'user/login',
					title: 'login'
					verification: 'successful'

