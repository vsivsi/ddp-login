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
  options.method ?= 'email'
  options.retry ?= 5
  options.plaintext ?= false
  switch options.method
    when 'username'
      method = tryOneUser
    when 'email'
      method = tryOneEmail
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

tryOneToken = (ddp, options, cb) ->
  ddp.call 'login', [{ resume: process.env[options.env] }], (err, res) ->
    return cb err, res?.token

attemptLogin = (ddp, user, pass, options, cb) ->
  hash = crypto.createHash 'sha256'
  hash.update pass, 'utf8'
  digest = { digest: hash.digest('hex'), algorithm: 'sha-256' }
  ddp.call 'login', [{user: user, password: digest}], (err, res) ->
    unless err and err.error is 400 and options.plaintext
      if err
        console.error 'Login failed:', err.message if err
      return cb err, res?.token

    # Fallback to plaintext login
    ddp.call 'login', [{user: user, password: pass}], (err, res) ->
      console.error 'Login failed: ', err.message if err
      return cb err, res?.token

tryOneEmail = (ddp, options, cb) ->
  async.series {
      email: async.apply read, {prompt: "Email: ", output: process.stderr}
      pw: async.apply read, {prompt: "Password: ", silent: true, output: process.stderr}
    },
    (err, res) ->
      return cb err if err
      attemptLogin ddp, {email: res.email[0]}, res.pw[0], options, cb

tryOneUser = (ddp, options, cb) ->
  async.series {
      user: async.apply read, {prompt: "Username: ", output: process.stderr}
      pw: async.apply read, {prompt: "Password: ", silent: true, output: process.stderr}
    },
    (err, res) ->
      return cb err if err
      attemptLogin ddp, {user: res.user[0]}, res.pw[0], options, cb

#
# When run standalone, the code below will execute
#

login._command_line = () ->

  yargs = require('yargs')
    .usage('''

Usage: $0 [--host <hostname>] [--port <portnum>] [--env <envvar>] [--method <logintype>] [--retry <count>] [--ssl] [--plaintext]

Output: a valid authToken, if successful

Note: If your Meteor server is older than v0.8.2, you will need to use the --plaintext
option to authenticate. If it is v0.8.2 or newer, but the account was created on an
an older server, you should re-authenticate once with a Meteor client to transition
the account to the post v0.8.2 account format. Otherwise, you must use --plaintext.
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
    .default('method', 'email')
    .describe('method', 'The login method: currently "email", "username" or "token"')
    .default('retry', '5')
    .describe('retry', 'Number of times to retry login before giving up')
    .describe('ssl', 'Use an SSL encrypted connection to connect with the host')
    .boolean('ssl')
    .default('ssl', false)
    .describe('plaintext', 'For accounts created on Meteor servers older than v0.8.2\nFallback to sending the password as plaintext.')
    .default('plaintext', false)
    .boolean('plaintext')
    .boolean('h')
    .alias('h','help')

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
    login ddp, { env: argv.env, method: argv.method, retry: argv.retry, plaintext: argv.plaintext }, (err, token) ->
      ddp.close()
      if err
        console.error "Login attempt failed with error:"
        console.dir err
        process.exit 1
        return
      console.log token
      process.exit 0
      return

  # ddp.on 'message', (msg) ->
  #   console.error("ddp message: " + msg)

module?.exports = login
