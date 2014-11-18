VerifyEmailController = require("./VerifyEmailController")

module.exports =
	apply: (app) ->
		app.get '/register/verifyEmail', VerifyEmailController.receiveVerification
