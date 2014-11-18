AdminController = require('./Features/ServerAdmin/AdminController')
ErrorController = require('./Features/Errors/ErrorController')
ProjectController = require("./Features/Project/ProjectController")
ProjectApiController = require("./Features/Project/ProjectApiController")
SpellingController = require('./Features/Spelling/SpellingController')
SecurityManager = require('./managers/SecurityManager')
AuthorizationManager = require('./Features/Security/AuthorizationManager')
EditorController = require("./Features/Editor/EditorController")
EditorHttpController = require("./Features/Editor/EditorHttpController")
EditorUpdatesController = require("./Features/Editor/EditorUpdatesController")
Settings = require('settings-sharelatex')
TpdsController = require('./Features/ThirdPartyDataStore/TpdsController')
SubscriptionRouter = require './Features/Subscription/SubscriptionRouter'
UploadsRouter = require './Features/Uploads/UploadsRouter'
metrics = require('./infrastructure/Metrics')
ReferalController = require('./Features/Referal/ReferalController')
ReferalMiddleware = require('./Features/Referal/ReferalMiddleware')
TemplatesRouter = require('./Features/Templates/TemplatesRouter')
TemplatesController = require('./Features/Templates/TemplatesController')
TemplatesMiddlewear = require('./Features/Templates/TemplatesMiddlewear')
AuthenticationController = require('./Features/Authentication/AuthenticationController')
TagsController = require("./Features/Tags/TagsController")
CollaboratorsController = require('./Features/Collaborators/CollaboratorsController')
UserInfoController = require('./Features/User/UserInfoController')
UserController = require("./Features/User/UserController")
UserPagesController = require('./Features/User/UserPagesController')
DocumentController = require('./Features/Documents/DocumentController')
CompileManager = require("./Features/Compile/CompileManager")
CompileController = require("./Features/Compile/CompileController")
HealthCheckController = require("./Features/HealthCheck/HealthCheckController")
ProjectDownloadsController = require "./Features/Downloads/ProjectDownloadsController"
FileStoreController = require("./Features/FileStore/FileStoreController")
TrackChangesController = require("./Features/TrackChanges/TrackChangesController")
PasswordResetRouter = require("./Features/PasswordReset/PasswordResetRouter")
VerifyEmailRouter = require("./Features/User/VerifyEmailRouter")
StaticPagesRouter = require("./Features/StaticPages/StaticPagesRouter")
ChatController = require("./Features/Chat/ChatController")
BlogController = require("./Features/Blog/BlogController")
WikiController = require("./Features/Wiki/WikiController")
ConnectedUsersController = require("./Features/ConnectedUsers/ConnectedUsersController")
DropboxRouter = require "./Features/Dropbox/DropboxRouter"
dropboxHandler = require "./Features/Dropbox/DropboxHandler"

logger = require("logger-sharelatex")
_ = require("underscore")

httpAuth = require('express').basicAuth (user, pass)->
	isValid = Settings.httpAuthUsers[user] == pass
	if !isValid
		logger.err user:user, pass:pass, "invalid login details"
	return isValid

module.exports = class Router
	constructor: (app, io, socketSessions)->
		app.use(app.router)
		
		app.get  '/login', UserPagesController.loginPage
		app.post '/login', AuthenticationController.login
		app.get  '/logout', UserController.logout
		app.get  '/restricted', SecurityManager.restricted

		app.get  '/register', UserPagesController.registerPage
		app.post '/register', UserController.register

		SubscriptionRouter.apply(app)
		UploadsRouter.apply(app)
		PasswordResetRouter.apply(app)
		VerifyEmailRouter.apply(app)
		StaticPagesRouter.apply(app)
		TemplatesRouter.apply(app)
		DropboxRouter.apply(app)

		app.get '/blog', BlogController.getIndexPage
		app.get '/blog/*', BlogController.getPage

		if Settings.enableSubscriptions
			app.get  '/user/bonus', AuthenticationController.requireLogin(), ReferalMiddleware.getUserReferalId, ReferalController.bonus

		app.get  '/user/settings', AuthenticationController.requireLogin(), UserPagesController.settingsPage
		app.post '/user/settings', AuthenticationController.requireLogin(), UserController.updateUserSettings
		app.post '/user/password/update', AuthenticationController.requireLogin(), UserController.changePassword

		app.del  '/user/newsletter/unsubscribe', AuthenticationController.requireLogin(), UserController.unsubscribe
		app.del  '/user', AuthenticationController.requireLogin(), UserController.deleteUser

		app.get  '/user/auth_token', AuthenticationController.requireLogin(), AuthenticationController.getAuthToken
		app.get  '/user/personal_info', AuthenticationController.requireLogin(allow_auth_token: true), UserInfoController.getLoggedInUsersPersonalInfo
		app.get  '/user/:user_id/personal_info', httpAuth, UserInfoController.getPersonalInfo

		app.get  '/project', AuthenticationController.requireLogin(), ProjectController.projectListPage
		app.post '/project/new', AuthenticationController.requireLogin(), ProjectController.newProject

		app.get '/project/new/template', TemplatesMiddlewear.saveTemplateDataInSession, AuthenticationController.requireLogin(), TemplatesController.createProjectFromZipTemplate

		app.get  '/Project/:Project_id', SecurityManager.requestCanAccessProject, ProjectController.loadEditor
		app.get  '/Project/:Project_id/file/:File_id', SecurityManager.requestCanAccessProject, FileStoreController.getFile

		app.post '/project/:Project_id/settings', SecurityManager.requestCanModifyProject, ProjectController.updateProjectSettings

		app.post '/project/:Project_id/doc', SecurityManager.requestCanModifyProject, EditorHttpController.addDoc
		app.post '/project/:Project_id/folder', SecurityManager.requestCanModifyProject, EditorHttpController.addFolder

		app.post '/project/:Project_id/:entity_type/:entity_id/rename', SecurityManager.requestCanModifyProject, EditorHttpController.renameEntity
		app.post '/project/:Project_id/:entity_type/:entity_id/move', SecurityManager.requestCanModifyProject, EditorHttpController.moveEntity
		app.delete '/project/:Project_id/:entity_type/:entity_id', SecurityManager.requestCanModifyProject, EditorHttpController.deleteEntity

		app.post '/project/:Project_id/compile', SecurityManager.requestCanAccessProject, CompileController.compile
		app.get  '/Project/:Project_id/output/output.pdf', SecurityManager.requestCanAccessProject, CompileController.downloadPdf
		app.get  /^\/project\/([^\/]*)\/output\/(.*)$/,
			((req, res, next) ->
				params =
					"Project_id": req.params[0]
					"file":       req.params[1]
				req.params = params
				next()
			), SecurityManager.requestCanAccessProject, CompileController.getFileFromClsi
		app.del "/project/:Project_id/output", SecurityManager.requestCanAccessProject, CompileController.deleteAuxFiles
		app.get "/project/:Project_id/sync/code", SecurityManager.requestCanAccessProject, CompileController.proxySync
		app.get "/project/:Project_id/sync/pdf", SecurityManager.requestCanAccessProject, CompileController.proxySync


		app.del  '/Project/:Project_id', SecurityManager.requestIsOwner, ProjectController.deleteProject
		app.post '/Project/:Project_id/restore', SecurityManager.requestIsOwner, ProjectController.restoreProject
		app.post '/Project/:Project_id/clone', SecurityManager.requestCanAccessProject, ProjectController.cloneProject

		app.post '/project/:Project_id/rename', SecurityManager.requestIsOwner, ProjectController.renameProject

		app.get  "/project/:Project_id/updates", SecurityManager.requestCanAccessProject, TrackChangesController.proxyToTrackChangesApi
		app.get  "/project/:Project_id/doc/:doc_id/diff", SecurityManager.requestCanAccessProject, TrackChangesController.proxyToTrackChangesApi
		app.post "/project/:Project_id/doc/:doc_id/version/:version_id/restore", SecurityManager.requestCanAccessProject, TrackChangesController.proxyToTrackChangesApi

		app.post "/project/:Project_id/doc/:doc_id/restore", SecurityManager.requestCanAccessProject, EditorHttpController.restoreDoc

		app.post '/project/:project_id/leave', AuthenticationController.requireLogin(), CollaboratorsController.removeSelfFromProject
		app.get  '/project/:Project_id/collaborators', SecurityManager.requestCanAccessProject(allow_auth_token: true), CollaboratorsController.getCollaborators

		app.get  '/project/:Project_id/connected_users', SecurityManager.requestCanAccessProject, ConnectedUsersController.getConnectedUsers

		app.get  '/Project/:Project_id/download/zip', SecurityManager.requestCanAccessProject, ProjectDownloadsController.downloadProject
		app.get  '/project/download/zip', SecurityManager.requestCanAccessMultipleProjects, ProjectDownloadsController.downloadMultipleProjects

		app.get '/tag', AuthenticationController.requireLogin(), TagsController.getAllTags
		app.post '/project/:project_id/tag', AuthenticationController.requireLogin(), TagsController.processTagsUpdate

		app.get  '/project/:project_id/details', httpAuth, ProjectApiController.getProjectDetails

		app.get '/internal/project/:Project_id/zip', httpAuth, ProjectDownloadsController.downloadProject
		app.get '/internal/project/:project_id/compile/pdf', httpAuth, CompileController.compileAndDownloadPdf


		app.get  '/project/:Project_id/doc/:doc_id', httpAuth, DocumentController.getDocument
		app.post '/project/:Project_id/doc/:doc_id', httpAuth, DocumentController.setDocument
		app.ignoreCsrf('post', '/project/:Project_id/doc/:doc_id')

		app.post '/user/:user_id/update/*', httpAuth, TpdsController.mergeUpdate
		app.del  '/user/:user_id/update/*', httpAuth, TpdsController.deleteUpdate
		app.ignoreCsrf('post', '/user/:user_id/update/*')
		app.ignoreCsrf('delete', '/user/:user_id/update/*')

		app.post "/spelling/check", AuthenticationController.requireLogin(), SpellingController.proxyRequestToSpellingApi
		app.post "/spelling/learn", AuthenticationController.requireLogin(), SpellingController.proxyRequestToSpellingApi

		app.get  "/project/:Project_id/messages", SecurityManager.requestCanAccessProject, ChatController.getMessages
		app.post "/project/:Project_id/messages", SecurityManager.requestCanAccessProject, ChatController.sendMessage
		
		app.get  /learn(\/.*)?/, WikiController.getPage

		#Admin Stuff
		app.get  '/admin', SecurityManager.requestIsAdmin, AdminController.index
		app.post '/admin/closeEditor', SecurityManager.requestIsAdmin, AdminController.closeEditor
		app.post '/admin/dissconectAllUsers', SecurityManager.requestIsAdmin, AdminController.dissconectAllUsers
		app.post '/admin/syncUserToSubscription', SecurityManager.requestIsAdmin, AdminController.syncUserToSubscription
		app.post '/admin/flushProjectToTpds', SecurityManager.requestIsAdmin, AdminController.flushProjectToTpds
		app.post '/admin/pollDropboxForUser', SecurityManager.requestIsAdmin, AdminController.pollDropboxForUser
		app.post '/admin/messages', SecurityManager.requestIsAdmin, AdminController.createMessage
		app.post '/admin/messages/clear', SecurityManager.requestIsAdmin, AdminController.clearMessages

		app.get '/perfTest', (req,res)->
			res.send("hello")
			req.session.destroy()

		app.get '/status', (req,res)->
			res.send("websharelatex is up")
			req.session.destroy()

		app.get '/health_check', HealthCheckController.check

		app.get "/status/compiler/:Project_id", SecurityManager.requestCanAccessProject, (req, res) ->
			sendRes = _.once (statusCode, message)->
				res.writeHead statusCode
				res.end message
			CompileManager.compile req.params.Project_id, "test-compile", {}, () ->
				sendRes 200, "Compiler returned in less than 10 seconds"
			setTimeout (() ->
				sendRes 500, "Compiler timed out"
			), 10000
			req.session.destroy()

		app.get '/test', (req, res) ->
			res.render "tests",
				privilegeLevel: "owner"
				project:
					name: "test"
				date: Date.now()
				layout: false
				userCanSeeDropbox: true
				languages: []

		app.get "/ip", (req, res, next) ->
			res.send({
				ip: req.ip
				ips: req.ips
				headers: req.headers
			})

		app.get '/oops-express', (req, res, next) -> next(new Error("Test error"))
		app.get '/oops-internal', (req, res, next) -> throw new Error("Test error")
		app.get '/oops-mongo', (req, res, next) ->
			require("./models/Project").Project.findOne {}, () ->
				throw new Error("Test error")

		app.post '/error/client', (req, res, next) ->
			logger.error err: req.body.error, meta: req.body.meta, "client side error"
			res.send(204)

		app.get '*', ErrorController.notFound

		socketSessions.on 'connection', (err, client, session)->
			metrics.inc('socket-io.connection')
			# This is not ideal - we should come up with a better way of handling
			# anonymous users, but various logging lines rely on user._id
			if !session or !session.user?
				user = {_id: "anonymous-user"}
			else
				user = session.user

			client.on 'joinProject', (data, callback) ->
				EditorController.joinProject(client, user, data.project_id, callback)

			client.on 'disconnect', () ->
				metrics.inc ('socket-io.disconnect')
				EditorController.leaveProject client, user

			client.on 'reportError', (error, callback) ->
				EditorController.reportError client, error, callback

			client.on 'sendUpdate', (doc_id, windowName, change)->
				AuthorizationManager.ensureClientCanEditProject client, (error, project_id) =>
					EditorUpdatesController.applyAceUpdate(client, project_id, doc_id, windowName, change)

			client.on 'applyOtUpdate', (doc_id, update) ->
				AuthorizationManager.ensureClientCanEditProject client, (error, project_id) =>
					EditorUpdatesController.applyOtUpdate(client, project_id, doc_id, update)

			client.on 'clientTracking.updatePosition', (cursorData) ->
				AuthorizationManager.ensureClientCanViewProject client, (error, project_id) =>
					EditorController.updateClientPosition(client, cursorData)

			client.on 'addUserToProject', (email, newPrivalageLevel, callback)->
				AuthorizationManager.ensureClientCanAdminProject client, (error, project_id) =>
					EditorController.addUserToProject project_id, email, newPrivalageLevel, callback

			client.on 'removeUserFromProject', (user_id, callback)->
				AuthorizationManager.ensureClientCanAdminProject client, (error, project_id) =>
					EditorController.removeUserFromProject(project_id, user_id, callback)

			client.on 'leaveDoc', (doc_id, callback)->
				AuthorizationManager.ensureClientCanViewProject client, (error, project_id) =>
					EditorController.leaveDoc(client, project_id, doc_id, callback)

			client.on 'joinDoc', (args...)->
				AuthorizationManager.ensureClientCanViewProject client, (error, project_id) =>
					EditorController.joinDoc(client, project_id, args...)

			# Deprecated and can be removed after deploying.
			client.on 'pdfProject', (opts, callback)->
				AuthorizationManager.ensureClientCanViewProject client, (error, project_id) =>
					CompileManager.compile project_id, user._id, opts, (error, status, outputFiles) ->
						return callback error, status == "success", outputFiles

			client.on 'getRootDocumentsList', (callback)->
				AuthorizationManager.ensureClientCanEditProject client, (error, project_id) =>
					EditorController.getListOfDocPaths project_id, callback

			client.on 'forceResyncOfDropbox', (callback)->
				AuthorizationManager.ensureClientCanAdminProject client, (error, project_id) =>
					EditorController.forceResyncOfDropbox project_id, callback

			client.on 'getUserDropboxLinkStatus', (owner_id, callback)->
				AuthorizationManager.ensureClientCanAdminProject client, (error, project_id) =>
					dropboxHandler.getUserRegistrationStatus owner_id, callback

			client.on 'publishProjectAsTemplate', (user_id, callback)->
				AuthorizationManager.ensureClientCanAdminProject client, (error, project_id) =>
					TemplatesController.publishProject user_id, project_id, callback

			client.on 'unPublishProjectAsTemplate', (user_id, callback)->
				AuthorizationManager.ensureClientCanAdminProject client, (error, project_id) =>
					TemplatesController.unPublishProject user_id, project_id, callback

			client.on 'updateProjectDescription', (description, callback)->
				AuthorizationManager.ensureClientCanEditProject client, (error, project_id) =>
					EditorController.updateProjectDescription project_id, description, callback

			client.on "getLastTimePollHappned", (callback)->
				EditorController.getLastTimePollHappned(callback)

			client.on "getPublishedDetails", (user_id, callback)->
				AuthorizationManager.ensureClientCanViewProject client, (error, project_id) =>
					TemplatesController.getTemplateDetails user_id, project_id, callback

