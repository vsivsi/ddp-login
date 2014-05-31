############################################################################
#     Copyright (C) 2014 by Vaughn Iverson
#     ddp-login is free software released under the MIT/X11 license.
#     See included LICENSE file for details.
############################################################################

read = require 'read'
DDP = require 'ddp'
async = require 'async'

login = (ddp, options..., cb) ->
  unless typeof cb is 'function'
    throw new Error 'Valid callback must be provided to ddp-login'
  unless ddp?.loginWithToken?
    return cb(new Error 'Invalid DDP parameter')
  options = options[0] ? {}
  options.env ?= 'METEOR_TOKEN'
  options.method ?= 'email'
  options.retry ?= 5
  switch options.method
    when 'username'
      method = tryOneUser
    when 'email'
      method = tryOneEmail
    else
      return cb(new Error "Unsupported DDP login method '#{options.method}'")

  if process.env[options.env]?
    # We're already logged-in, maybe...
    ddp.loginWithToken process.env[options.env], (err, res) ->
      unless err or not res
        return cb null, res?.token
      else
        return async.retry options.retry, async.apply(method, ddp), cb
  else
    return async.retry options.retry, async.apply(method, ddp), cb

tryOneEmail = (ddp, cb) ->
  async.series {
      email: async.apply read, {prompt: "Email: ", output: process.stderr}
      pw: async.apply read, {prompt: "Password: ", silent: true, output: process.stderr}
    },
    (err, res) ->
      return cb err if err
      ddp.loginWithEmail res.email[0], res.pw[0], (err, res) ->
        return cb err, res?.token

tryOneUser = (ddp, cb) ->
  async.series {
      user: async.apply read, {prompt: "Username: ", output: process.stderr}
      pw: async.apply read, {prompt: "Password: ", silent: true, output: process.stderr}
    },
    (err, res) ->
      return cb err if err
      ddp.loginWithUsername res.user[0], res.pw[0], (err, res) ->
        return cb err, res?.token

#
# When run standalone, the code below will execute
#

login._command_line = () ->

  yargs = require('yargs')
    .usage('''

Usage: node ddp-login [--host <hostname>] [--port <portnum>] [--env <envvar>] [--method <logintype>] [--retry <count>]

Output: a valid authToken, if successful

Example: export METEOR_TOKEN=$($0 --host 127.0.0.1 --port 3000 --env METEOR_TOKEN --method email --retry 5)
''')
    .default('host', '127.0.0.1')
    .describe('host', 'The domain name or IP address of the host to connect with')
    .default('port', 3000)
    .describe('port', 'The server port number to connect with')
    .default('env', 'METEOR_TOKEN')
    .describe('env', 'The environment variable to check for a valid token')
    .default('method', 'email')
    .describe('method', 'The login method: currently either "email" or "username"')
    .default('retry', '5')
    .describe('retry', 'Number of times to retry login before giving up')
    .boolean('h')
    .alias('h','help')

  argv = yargs.argv

  if argv.h
    yargs.showHelp()
    process.exit 1

  ddp = new DDP
    host: argv.host
    port: argv.port
    use_ejson: true

  ddp.connect (err) ->
    throw err if err
    login ddp, { env: argv.env, method: argv.method, retry: parseInt(argv.retry) }, (err, token) ->
      ddp.close()
      if err
        console.error "Login attempt failed with error:"
        console.dir err
        process.exit 1
      console.log token
      process.exit 0

  # ddp.on 'message', (msg) ->
  #   console.error("ddp message: " + msg)

module?.exports = login
