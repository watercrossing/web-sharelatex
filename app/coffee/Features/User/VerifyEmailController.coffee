VerifyEmailHandler = require("./VerifyEmailHandler")
logger = require("logger-sharelatex")
Url = require("url")

module.exports =
	receiveVerification : (req, res) ->
		code = req.query.code
		logger.log "Received verification code #{code}"
		redir = Url.parse(req.body?.redir or "/project").path
		if !code? or code.length == 0
			return res.send 500
		VerifyEmailHandler.verifyToken code.trim(), (err) ->
			if err?
				res.send message:
					text: "Verification token is incorrect."
					type: "error"
			else
				res.render 'user/login',
					title: 'login'
					verification: 'successful'

