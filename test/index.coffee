############################################################################
#     Copyright (C) 2014-2015 by Vaughn Iverson
#     ddp-login is free software released under the MIT/X11 license.
#     See included LICENSE file for details.
############################################################################

# Unit tests

assert = require('chai').assert
rewire = require 'rewire'
sinon = require 'sinon'

login = null

login = rewire '../src/index.coffee'

read = (obj, cb) ->
   process.nextTick () ->
      val = switch obj.prompt
         when "Email: "
            email
         when "Username: "
            user
         when "Account: "
            account
         when "Password: "
            pass
         else
            throw new Error 'Bad prompt in read mock'
      cb null, val, false

class DDP

   connect: (cb) ->
      # console.log "DDP Connecting..."
      process.nextTick cb

   close: (cb) ->
      # console.log "DDP Closing..."

   call: (method, params, cb) ->

      process.nextTick () ->

         unless method is 'login'
            return cb methodNotFoundError

         obj = params[0]

         if obj.resume? # Token based auth

            if obj.resume is goodToken
               return cb null, { token: goodToken }
            else
               return cb loggedOutError

         else if obj.user? and obj.password? # password

            if obj.password.digest?
               unless obj.password.algorithm is 'sha-256'
                  return cb unrecognizedOptionsError
            else unless typeof obj.password is 'string'
               return cb unrecognizedOptionsError

            if obj.user.username? # username based
               if obj.user.username is user and
                 (obj.password is okpass or obj.password.digest is goodDigest)
                  return cb null, { token: goodToken }
               else if obj.user.username is srpUser
                  if obj.srp? and obj.password.digest is goodDigest
                     if obj.srp is 'c398c8dce734b1a6e7959bf90067985a1291e9f32a62edf15efb5adc760e40ce'
                        return cb null, { token: migrationToken }
                     else
                        return cb matchFailedError
                  else
                     return cb oldPasswordFormatError
               else
                  return cb matchFailedError

            else if obj.user.email # email based
               if obj.user.email is email and
                 (obj.password is okpass or obj.password.digest is goodDigest)
                  return cb null, { token: goodToken }
               else
                  return cb matchFailedError
            else
               return cb unrecognizedOptionsError
         else
            return cb unrecognizedOptionsError

login.__set__ 'read', read
login.__set__ 'DDP', DDP

goodToken = 'Ge1KTcEL8MbPc7hq_M5OkOwKHtNzbCdiDqaEoUNux22'
migrationToken = 'Cn55fidCmxKykJsQd4VPUU0aHIOGom0HjdOELYkM8Vg'
badToken = 'slkf90sfj3fls9j930fjfssjf9jf3fjs_fssh82344f'

matchFailedError =
   "error":400
   "reason":"Match failed"
   "message":"Match failed [400]"
   "errorType":"Meteor.Error"

loggedOutError =
   "error":403
   "reason":"You've been logged out by the server. Please log in again."
   "message":"You've been logged out by the server. Please log in again. [403]"
   "errorType":"Meteor.Error"

methodNotFoundError =
   "error":404
   "reason":"Method not found"
   "message":"Method not found [404]"
   "errorType":"Meteor.Error"

unrecognizedOptionsError =
   "error":400
   "reason":"Unrecognized options for login request"
   "message":"Unrecognized options for login request [400]"
   "errorType":"Meteor.Error"

oldPasswordFormatError =
   "error":400
   "reason":"old password format"
   "details":'{"format":"srp","identity":"h_UZJgkIqF-NYPR-NSJzHvZWH9MuHb689eLzy741nXq"}'
   "message":"old password format [400]"
   "errorType":"Meteor.Error"

user = 'Bozo'
email = 'bozo@clowns.com'
account = null
srpUser = 'Crusty'
goodpass = 'secure'
goodDigest = '6a934b45144e3758911efa29ed68fb2d420fa7bd568739cdcda9251fa9609b1e'
okpass = 'justok'
badpass = 'insecure'
pass = null

ddp = new DDP()

describe 'ddp-login', () ->

   describe 'API', () ->

      before () ->
         login.__set__
            console:
               error: (m) ->

      describe 'login with SRP account migration', () ->

         it 'should return a valid authToken when an account migration is successful', (done) ->
            pass = goodpass
            account = srpUser
            login ddp, { method: "account" }, (e, res) ->
               assert.ifError e
               assert.equal res.token, migrationToken, 'Wrong token returned'
               done()

         afterEach () ->
            pass = null

      it 'should throw when invoked without a valid callback', () ->
         assert.throws login, /Valid callback must be provided to ddp-login/

      it 'should require a valid ddp parameter', () ->
         login null, (e) ->
            assert.throws (() -> throw e), /Invalid DDP parameter/

      it 'should reject unsupported login methods', () ->
         login { call: (->), connect: (->), close: (->)}, { method: 'bogus' }, (e) ->
            assert.throws (() -> throw e), /Unsupported DDP login method/

      it 'should recognize valid email addresses', () ->
         isEmail = login.__get__ 'isEmail'
         assert.isTrue isEmail(email), 'Valid email #1'
         assert.isTrue isEmail('CAPS.CAPS@DOMAIN.MUSEUM'), 'Valid email #2'
         assert.isFalse isEmail('not an email'), 'Invalid email #1'
         assert.isFalse isEmail('bozo@clown'), 'Invalid email #2'
         assert.isFalse isEmail('bozo@clown@clowns.com'), 'Invalid email #3'

      describe 'authToken handling', () ->

         it 'should return an existing valid authToken in the default environment variable', (done) ->
            process.env.METEOR_TOKEN = goodToken
            login ddp, (e, res) ->
               assert.ifError e
               assert.equal res.token, goodToken, 'Wrong token returned'
               process.env.METEOR_TOKEN = undefined
               done()

         it 'should return an existing valid authToken in a specified environment variable', (done) ->
            process.env.TEST_TOKEN = goodToken
            login ddp, { env: 'TEST_TOKEN' }, (e, res) ->
               assert.ifError e
               assert.equal res.token, goodToken, 'Wrong token returned'
               process.env.TEST_TOKEN = undefined
               done()

      describe 'login with token only', () ->

         it 'should return a valid authToken when successful', (done) ->
            process.env.METEOR_TOKEN = goodToken
            login ddp, { method: 'token' }, (e, res) ->
               assert.ifError e
               assert.equal res.token, goodToken, 'Wrong token returned'
               done()

         it 'should retry 5 times by default and then fail with bad credentials', (done) ->
            process.env.METEOR_TOKEN = badToken
            sinon.spy ddp, 'call'
            login ddp, { method: 'token' }, (e, res) ->
               assert.equal e, loggedOutError
               assert.equal ddp.call.callCount, 6
               ddp.call.restore()
               done()

         it 'should retry the specified number of times and then fail with bad credentials', (done) ->
            process.env.METEOR_TOKEN = badToken
            sinon.spy ddp, 'call'
            login ddp, { method: 'token', retry: 3 }, (e, res) ->
               assert.equal e, loggedOutError
               assert.equal ddp.call.callCount, 4
               ddp.call.restore()
               done()

         afterEach () ->
            process.env.METEOR_TOKEN = undefined

      describe 'login with email', () ->

         it 'should return a valid authToken when successful', (done) ->
            pass = goodpass
            account = email
            login ddp, (e, res) ->
               assert.ifError e
               assert.equal res.token, goodToken, 'Wrong token returned'
               done()

         it 'should also work when method is set to email', (done) ->
            pass = goodpass
            login ddp, { method: 'email' }, (e, res) ->
               assert.ifError e
               assert.equal res.token, goodToken, 'Wrong token returned'
               done()

         it 'should work when account and pass are provided as options', (done) ->
            login ddp, { account: email, pass: goodpass }, (e, res) ->
               assert.ifError e
               assert.equal res.token, goodToken, 'Wrong token returned'
               done()

         it 'should retry 5 times by default and then fail with bad credentials', (done) ->
            pass = badpass
            account = email
            sinon.spy ddp, 'call'
            login ddp, (e, res) ->
               assert.equal e, matchFailedError
               assert.equal ddp.call.callCount, 11
               ddp.call.restore()
               done()

         it 'should successfully authenticate with plaintext credentials', (done) ->
            pass = okpass
            account = email
            login ddp, { plaintext: true }, (e, res) ->
               assert.ifError e
               assert.equal res.token, goodToken, 'Wrong token returned'
               done()

         it 'should retry the specified number of times and then fail with bad credentials', (done) ->
            pass = badpass
            account = email
            sinon.spy ddp, 'call'
            login ddp, { retry: 3 }, (e, res) ->
               assert.equal e, matchFailedError
               assert.equal ddp.call.callCount, 7
               ddp.call.restore()
               done()

         afterEach () ->
            pass = null
            account = null

      describe 'login with username', () ->

         it 'should return a valid authToken when successful', (done) ->
            pass = goodpass
            account = user
            login ddp, (e, res) ->
               assert.ifError e
               assert.equal res.token, goodToken, 'Wrong token returned'
               done()

         it 'should also work when method is set to username', (done) ->
            pass = goodpass
            login ddp, { method: 'username' }, (e, res) ->
               assert.ifError e
               assert.equal res.token, goodToken, 'Wrong token returned'
               done()

         it 'should work when account and pass are provided as options', (done) ->
            login ddp, { account: user, pass: goodpass }, (e, res) ->
               assert.ifError e
               assert.equal res.token, goodToken, 'Wrong token returned'
               done()

         it 'should retry 5 times by default and then fail with bad credentials', (done) ->
            pass = badpass
            account = user
            sinon.spy ddp, 'call'
            login ddp, (e, res) ->
               assert.equal e, matchFailedError
               assert.equal ddp.call.callCount, 6
               ddp.call.restore()
               done()

         it 'should retry the specified number of times and then fail with bad credentials', (done) ->
            pass = badpass
            account = user
            sinon.spy ddp, 'call'
            login ddp, { retry: 3 }, (e, res) ->
               assert.equal e, matchFailedError
               assert.equal ddp.call.callCount, 4
               ddp.call.restore()
               done()

         afterEach () ->
            pass = null
            account = null

      after () ->
         login.__set__
            console: console

   describe 'Command line', () ->

      newLogin = () ->
         login = rewire '../src/index.coffee'
         login.__set__ 'read', read
         login.__set__ "DDP", DDP

      beforeEach () -> newLogin()

      it 'should support logging in with all default parameters with username', (done) ->
         pass = goodpass
         account = user
         token = null
         login.__set__
            console:
               log: (m) ->
                  token = m
               warn: console.warn
            process:
               env: {}
               argv: []
               exit: (n) ->
                  assert.equal n, 0
                  assert.equal token, goodToken
                  done()
         login._command_line()

      it 'should support logging in with all default parameters with email', (done) ->
         pass = goodpass
         account = email
         token = null
         login.__set__
            console:
               log: (m) ->
                  token = m
               warn: console.warn
            process:
               env: {}
               argv: []
               exit: (n) ->
                  assert.equal n, 0
                  assert.equal token, goodToken
                  done()
         login._command_line()

      it 'should fail logging in with bad credentials', (done) ->
         pass = badpass
         account = email
         token = null
         login.__set__
            console:
               log: (m) ->
                  token = m
               error: (m) ->
               warn: console.warn
               dir: (o) ->
            process:
               env: {}
               argv: []
               exit: (n) ->
                  assert.equal n, 1
                  done()
         login._command_line()

      it 'should support logging in with username', (done) ->
         pass = goodpass
         token = null
         login.__set__
            console:
               log: (m) ->
                  token = m
               warn: console.warn
            process:
               env: {}
               argv: ['node', 'ddp-login', '--method', 'username']
               exit: (n) ->
                  assert.equal n, 0
                  assert.equal token, goodToken
                  done()
         login._command_line()

      it 'should fail logging in with bad username credentials', (done) ->
         pass = badpass
         token = null
         login.__set__
            console:
               log: (m) ->
                  token = m
               error: (m) ->
               warn: console.warn
               dir: (o) ->
            process:
               env: {}
               argv: ['node', 'ddp-login', '--method', 'username']
               exit: (n) ->
                  assert.equal n, 1
                  done()
         login._command_line()

      it 'should properly pass host and port to DDP', (done) ->
         pass = goodpass
         account = email
         token = null
         spyDDP = sinon.spy(DDP)
         login.__set__ "DDP", spyDDP
         login.__set__
            console:
               log: (m) ->
                  token = m
               warn: console.warn
            process:
               env: {}
               argv: ['node', 'ddp-login', '--host', 'localhost', '--port', '3333']
               exit: (n) ->
                  assert.equal n, 0
                  assert.equal token, goodToken
                  assert spyDDP.calledWithExactly
                     host: 'localhost'
                     port: 3333
                     use_ssl: false
                     use_ejson: true
                  done()
         login._command_line()

      it 'should succeed when a good token is in the default env var', (done) ->
         pass = badpass
         token = null
         login.__set__ "DDP", DDP
         login.__set__
            console:
               log: (m) ->
                  token = m
               warn: console.warn
            process:
               env:
                  METEOR_TOKEN: goodToken
               argv: []
               exit: (n) ->
                  assert.equal n, 0, 'wrong return code'
                  assert.equal token, goodToken, 'Bad token'
                  done()
         login._command_line()

      it 'should succeed when a good token is in the default env var and method is "token"', (done) ->
         pass = badpass
         token = null
         login.__set__ "DDP", DDP
         login.__set__
            console:
               log: (m) ->
                  token = m
               warn: console.warn
            process:
               env:
                  METEOR_TOKEN: goodToken
               argv: ['node', 'ddp-login', '--method', 'token']
               exit: (n) ->
                  assert.equal n, 0, 'wrong return code'
                  assert.equal token, goodToken, 'Bad token'
                  done()
         login._command_line()

      it 'should succeed when a good token is in a specified env var', (done) ->
         pass = badpass
         token = null
         login.__set__ "DDP", DDP
         login.__set__
            console:
               log: (m) ->
                  token = m
               warn: console.warn
            process:
               env:
                  TEST_TOKEN: goodToken
               argv: ['node', 'ddp-login', '--env', 'TEST_TOKEN']
               exit: (n) ->
                  assert.equal n, 0, 'wrong return code'
                  assert.equal token, goodToken, 'Bad token'
                  done()
         login._command_line()

      it 'should succeed when a good token is in a specified env var and method is "token"', (done) ->
         pass = badpass
         token = null
         login.__set__ "DDP", DDP
         login.__set__
            console:
               log: (m) ->
                  token = m
               warn: console.warn
            process:
               env:
                  TEST_TOKEN: goodToken
               argv: ['node', 'ddp-login', '--env', 'TEST_TOKEN', '--method', 'token']
               exit: (n) ->
                  assert.equal n, 0, 'wrong return code'
                  assert.equal token, goodToken, 'Bad token'
                  done()
         login._command_line()

      it 'should succeed when a bad token is in a specified env var', (done) ->
         pass = goodpass
         account = email
         token = null
         login.__set__
            console:
               log: (m) ->
                  token = m
               warn: console.warn
            process:
               env:
                  TEST_TOKEN: badToken
               argv: ['node', 'ddp-login', '--env', 'TEST_TOKEN']
               exit: (n) ->
                  assert.equal n, 0, 'wrong return code'
                  assert.equal token, goodToken, 'Bad token'
                  done()
         login._command_line()

      it 'should fail logging in with bad token when method is "token"', (done) ->
         pass = goodpass
         login.__set__
            console:
               log: (m) ->
                  token = m
               error: (m) ->
               warn: console.warn
               dir: (o) ->
            process:
               env:
                  METEOR_TOKEN: badToken
               argv: ['node', 'ddp-login', '--method', 'token']
               exit: (n) ->
                  assert.equal n, 1
                  done()
         login._command_line()

      it 'should fail logging in with bad token in specified env var when method is "token"', (done) ->
         pass = goodpass
         login.__set__
            console:
               log: (m) ->
                  token = m
               error: (m) ->
               warn: console.warn
               dir: (o) ->
            process:
               env:
                  TEST_TOKEN: badToken
               argv: ['node', 'ddp-login', '--env', 'TEST_TOKEN', '--method', 'token']
               exit: (n) ->
                  assert.equal n, 1
                  done()
         login._command_line()

      it 'should retry 5 times by default', (done) ->
         pass = badpass
         token = null
         sinon.spy DDP.prototype, 'call'
         login.__set__
            console:
               log: (m) ->
                  token = m
               error: (m) ->
               warn: console.warn
               dir: (o) ->
            process:
               env:
                  TEST_TOKEN: badToken
               argv: ['node', 'ddp-login', '--env', 'TEST_TOKEN']
               exit: (n) ->
                  assert.equal n, 1
                  assert.equal DDP.prototype.call.callCount, 6
                  DDP.prototype.call.restore()
                  done()
         login._command_line()

      it 'should retry the specified number of times', (done) ->
         pass = badpass
         token = null
         sinon.spy DDP.prototype, 'call'
         login.__set__
            console:
               log: (m) ->
                  token = m
               error: (m) ->
               warn: console.warn
               dir: (o) ->
            process:
               env:
                  TEST_TOKEN: badToken
               argv: ['node', 'ddp-login', '--env', 'TEST_TOKEN', '--retry', '3']
               exit: (n) ->
                  assert.equal n, 1
                  assert.equal DDP.prototype.call.callCount, 4
                  DDP.prototype.call.restore()
                  done()
         login._command_line()

      afterEach () ->
         pass = null
         account = null
