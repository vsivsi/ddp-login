############################################################################
#     Copyright (C) 2014 by Vaughn Iverson
#     ddp-login is free software released under the MIT/X11 license.
#     See included LICENSE file for details.
############################################################################

read = require 'read'
DDP = require 'ddp'
async = require 'async'
crypto = require 'crypto'

login = (ddp, options..., cb) ->

  unless typeof cb is 'function'
    throw new Error 'Valid callback must be provided to ddp-login'
  unless ddp?.call? and ddp?.connect? and ddp?.close?
    return cb(new Error 'Invalid DDP parameter')
  options = options[0] ? {}
  options.env ?= 'METEOR_TOKEN'
  options.method ?= 'account'
  options.retry ?= 5
  options.plaintext ?= false
  options.account ?= null
  options.pass ?= null

  switch options.method
    when 'username'
      method = tryOneUser
    when 'email'
      method = tryOneEmail
    when 'account'
      method = tryOneAccount
    when 'token'
      method = tryOneToken
    else
      return cb(new Error "Unsupported DDP login method '#{options.method}'")

  if process.env[options.env]?
    # We're already logged-in, maybe...
    tryOneToken ddp, options, (err, res) ->
      unless err or not res
        return cb null, res
      else
        return async.retry options.retry, async.apply(method, ddp, options), cb
  else
    return async.retry options.retry, async.apply(method, ddp, options), cb

plaintextToDigest = (pass) ->
  hash = crypto.createHash 'sha256'
  hash.update pass, 'utf8'
  return hash.digest('hex')

isEmail = (addr) ->
  unless typeof addr is 'string'
    return false
  matchEmail = ///
      ^
      [^@]+
      @
      [^@]+\.[^@]+
      $
    ///i
  m = addr.match matchEmail
  m isnt null

attemptLogin = (ddp, user, pass, options, cb) ->
  digest = plaintextToDigest pass
  ddp.call 'login', [{user: user, password: {digest: digest, algorithm: 'sha-256' }}], (err, res) ->
    unless err and err.error is 400
      if err
        console.error 'Login failed:', err.message
      return cb err, res

    if err.reason is 'old password format'

      # Attempt to migrate from pre v0.8.2 SRP account to bcrypt account
      console.error 'Old Meteor SRP (pre-v0.8.2) account detected. Attempting to migrate...'
      try
        details = JSON.parse err.details
      catch e
        return cb err

      srpDigest = plaintextToDigest "#{details.identity}:#{pass}"
      ddp.call 'login', [{user: user, srp: srpDigest, password: {digest: digest, algorithm: 'sha-256'}}], cb

    else if options.plaintext
      # Fallback to plaintext login
      ddp.call 'login', [{user: user, password: pass}], (err, res) ->
        console.error 'Login failed: ', err.message if err
        return cb err, res
    else
      return cb err, res

loginWithUsername = (ddp, username, password, options..., cb) ->
   attemptLogin ddp, {username: username}, password, options[0], cb

loginWithEmail = (ddp, email, password, options..., cb) ->
   attemptLogin ddp, {email: email}, password, options[0], cb

loginWithAccount = (ddp, account, password, options..., cb) ->
  if isEmail account
    loginWithEmail ddp, account, password, options[0], (err, tok) ->
      return cb err, tok unless err and err.error is 400
      loginWithUsername ddp, account, password, options[0], cb
  else
    loginWithUsername ddp, account, password, options[0], cb

loginWithToken = (ddp, token, cb) ->
  ddp.call 'login', [{ resume: token }], cb

tryOneToken = (ddp, options, cb) ->
  loginWithToken ddp, process.env[options.env], (err, res) ->
    return cb err, res

userPrompt = (prompt, options, cb) ->
  readPrompts = {}
  unless options.account?
    readPrompts.account = async.apply read, {prompt: prompt, output: process.stderr}
  unless options.pass?
    readPrompts.pass = async.apply read, {prompt: 'Password: ', silent: true, output: process.stderr}

  async.series readPrompts, (err, res) ->
    cb err if err
    result = {}
    result.account = res.account?[0] or options.account
    result.pass = res.pass?[0] or options.pass
    cb null, result

tryOneEmail = (ddp, options, cb) ->
  userPrompt "Email: ", options, (err, res) ->
    return cb err if err
    loginWithEmail ddp, res.account, res.pass, options, cb

tryOneUser = (ddp, options, cb) ->
  userPrompt "Username: ", options, (err, res) ->
    return cb err if err
    loginWithUsername ddp, res.account, res.pass, options, cb

tryOneAccount = (ddp, options, cb) ->
  userPrompt "Account: ", options, (err, res) ->
    return cb err if err
    loginWithAccount ddp, res.account, res.pass, options, cb

#
# When run standalone, the code below will execute
#

login._command_line = () ->

  yargs = require('yargs')
    .usage('''

Usage: $0 [--host <hostname>] [--port <portnum>] [--env <envvar>] [--method <logintype>] [--retry <count>] [--ssl] [--plaintext]

Output: a valid authToken, if successful

Note: If your Meteor server is older than v0.8.2, you will need to use the --plaintext option to authenticate.
''')
    .example('', '''

export METEOR_TOKEN=$($0 --host 127.0.0.1 --port 3000 --env METEOR_TOKEN --method email --retry 5)
''')
    .default('host', '127.0.0.1')
    .describe('host', 'The domain name or IP address of the host to connect with')
    .default('port', 3000)
    .describe('port', 'The server port number to connect with')
    .default('env', 'METEOR_TOKEN')
    .describe('env', 'The environment variable to check for a valid token')
    .default('method', 'account')
    .describe('method', 'The login method: currently "email", "username", "account" or "token"')
    .default('retry', 5)
    .describe('retry', 'Number of times to retry login before giving up')
    .describe('ssl', 'Use an SSL encrypted connection to connect with the host')
    .boolean('ssl')
    .default('ssl', false)
    .describe('plaintext', 'For Meteor servers older than v0.8.2, fallback to sending the password as plaintext')
    .default('plaintext', false)
    .boolean('plaintext')
    .boolean('h')
    .alias('h','help')
    .wrap(null)
    .version((() -> require('../package').version))

  argv = yargs.parse(process.argv)

  if argv.h
    yargs.showHelp()
    process.exit 1

  ddp = new DDP
    host: argv.host
    port: argv.port
    use_ssl: argv.ssl
    use_ejson: true

  ddp.connect (err) ->
    throw err if err
    login ddp, { env: argv.env, method: argv.method, retry: argv.retry, plaintext: argv.plaintext }, (err, res) ->
      ddp.close()
      if err
        console.error "Login attempt failed with error:"
        console.dir err
        process.exit 1
        return
      console.log res.token
      process.exit 0
      return

  # ddp.on 'message', (msg) ->
  #   console.error("ddp message: " + msg)

login.loginWithToken = loginWithToken
login.loginWithUsername = loginWithUsername
login.loginWithEmail = loginWithEmail
login.loginWithAccount = loginWithAccount

module?.exports = login
