# Unit tests

assert = require 'assert'
rewire = require 'rewire'
sinon = require 'sinon'
# ddp = require 'ddp'

login = null

login = rewire '../src/index.coffee'

read = (obj, cb) ->
   process.nextTick () ->
      val = switch obj.prompt
         when "Email: "
            email
         when "Username: "
            user
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

   loginWithToken: (token, cb) ->
      process.nextTick () ->
         if token is goodToken
            return cb null, { token: goodToken }
         else
            return cb(new Error "Bad token")

   loginWithEmail: (em, pw, cb) ->
      process.nextTick () ->
         if em is 'bozo@clowns.com' and pw is 'secure'
            return cb null, { token: goodToken }
         else
            return cb(new Error "Bad email credentials")

   loginWithUsername: (un, pw, cb) ->
      process.nextTick () ->
         if un is 'bozo' and pw is 'secure'
            return cb null, { token: goodToken }
         else
            return cb(new Error "Bad username credentials")

login.__set__ 'read', read
login.__set__ 'DDP', DDP

goodToken = 'Ge1KTcEL8MbPc7hq_M5OkOwKHtNzbCdiDqaEoUNux22'
badToken =  'slkf90sfj3fls9j930fjfssjf9jf3fjs_fssh82344f'

user = 'bozo'
email = 'bozo@clowns.com'
goodpass = 'secure'
badpass = 'insecure'
pass = null

ddp = new DDP()

describe 'ddp-login', () ->

   describe 'API', () ->

      it 'should throw when invoked without a valid callback', () ->
         assert.throws login, /Valid callback must be provided to ddp-login/

      it 'should require a valid ddp parameter', () ->
         login null, (e) ->
            assert.throws (() -> throw e), /Invalid DDP parameter/

      it 'should reject unsupported login methods', () ->
         login { loginWithToken: () -> }, { method: 'bogus' }, (e) ->
            assert.throws (() -> throw e), /Unsupported DDP login method/

      describe 'authToken handling', () ->

         it 'should return an existing valid authToken in the default environment variable', (done) ->
            process.env.METEOR_TOKEN = goodToken
            login ddp, (e, token) ->
               assert.ifError e
               assert.equal token, goodToken, 'Wrong token returned'
               process.env.METEOR_TOKEN = undefined
               done()

         it 'should return an existing valid authToken in a specified environment variable', (done) ->
            process.env.TEST_TOKEN = goodToken
            login ddp, { env: 'TEST_TOKEN' }, (e, token) ->
               assert.ifError e
               assert.equal token, goodToken, 'Wrong token returned'
               process.env.TEST_TOKEN = undefined
               done()

      describe 'login with email', () ->

         it 'should return a valid authToken when successful', (done) ->
            pass = goodpass
            login ddp, (e, token) ->
               assert.ifError e
               assert.equal token, goodToken, 'Wrong token returned'
               done()

         it 'should also work when method is set to email', (done) ->
            pass = goodpass
            login ddp, { method: 'email' }, (e, token) ->
               assert.ifError e
               assert.equal token, goodToken, 'Wrong token returned'
               done()

         it 'should retry 5 times by default and then fail with bad credentials', (done) ->
            pass = badpass
            sinon.spy ddp, 'loginWithEmail'
            login ddp, (e, token) ->
               assert.throws (() -> throw e), /Bad email credentials/
               assert.equal ddp.loginWithEmail.callCount, 5
               ddp.loginWithEmail.restore()
               done()

         it 'should retry the specified number of times and then fail with bad credentials', (done) ->
            pass = badpass
            sinon.spy ddp, 'loginWithEmail'
            login ddp, { retry: 3 }, (e, token) ->
               assert.throws (() -> throw e), /Bad email credentials/
               assert.equal ddp.loginWithEmail.callCount, 3
               ddp.loginWithEmail.restore()
               done()

         afterEach () ->
            pass = null

      describe 'login with username', () ->

         it 'should return a valid authToken when successful', (done) ->
            pass = goodpass
            login ddp, { method: 'username' }, (e, token) ->
               assert.ifError e
               assert.equal token, goodToken, 'Wrong token returned'
               done()

         it 'should retry 5 times by default and then fail with bad credentials', (done) ->
            pass = badpass
            sinon.spy ddp, 'loginWithUsername'
            login ddp, { method: 'username' }, (e, token) ->
               assert.throws (() -> throw e), /Bad username credentials/
               assert.equal ddp.loginWithUsername.callCount, 5
               ddp.loginWithUsername.restore()
               done()

         it 'should retry the specified number of times and then fail with bad credentials', (done) ->
            pass = badpass
            sinon.spy ddp, 'loginWithUsername'
            login ddp, { method: 'username', retry: 3 }, (e, token) ->
               assert.throws (() -> throw e), /Bad username credentials/
               assert.equal ddp.loginWithUsername.callCount, 3
               ddp.loginWithUsername.restore()
               done()

         afterEach () ->
            pass = null

   describe 'Command line', () ->

      newLogin = () ->
         login = rewire '../src/index.coffee'
         login.__set__ 'read', read
         login.__set__ "DDP", DDP

      beforeEach () -> newLogin()

      it 'should support logging in with all default parameters', (done) ->
         pass = goodpass
         token = null
         login.__set__
            console:
               log: (m) ->
                  token = m
               warn: console.warn
         login.__set__ 'process.exit', (n) ->
            assert.equal n, 0
            assert.equal token, goodToken
            done()
         login._command_line()

      it 'should fail logging in with bad credentials', (done) ->
         pass = badpass
         token = null
         login.__set__
            console:
               log: (m) ->
                  token = m
               error: (m) ->
               warn: console.warn
               dir: (o) ->
         login.__set__ 'process.exit', (n) ->
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
         login.__set__ 'process.exit', (n) ->
            assert.equal n, 0
            assert.equal token, goodToken
            done()
         login.__set__ 'process.argv', ['node', 'ddp-login', '--method', 'username']
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
         login.__set__ 'process.exit', (n) ->
            assert.equal n, 1
            done()
         login.__set__ 'process.argv', ['node', 'ddp-login', '--method', 'username']
         login._command_line()

      it 'should properly pass host and port to DDP', (done) ->
         pass = goodpass
         token = null
         spyDDP = sinon.spy(DDP)
         login.__set__ "DDP", spyDDP
         login.__set__
            console:
               log: (m) ->
                  token = m
               warn: console.warn
         login.__set__ 'process.exit', (n) ->
            assert.equal n, 0
            assert.equal token, goodToken
            assert spyDDP.calledWithExactly
               host: 'localhost'
               port: 3333
               use_ejson: true
            done()
         login.__set__ 'process.argv', ['node', 'ddp-login', '--host', 'localhost', '--port', '3333']
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
         login.__set__ 'process.exit', (n) ->
            assert.equal n, 0, 'wrong return code'
            assert.equal token, goodToken, 'Bad token'
            done()
         login.__set__ 'process.env.METEOR_TOKEN', goodToken
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
         login.__set__ 'process.exit', (n) ->
            assert.equal n, 0, 'wrong return code'
            assert.equal token, goodToken, 'Bad token'
            done()
         login.__set__ 'process.env.TEST_TOKEN', goodToken
         login.__set__ 'process.argv', ['node', 'ddp-login', '--env', 'TEST_TOKEN']
         login._command_line()

      it 'should succeed when a bad token is in a specified env var', (done) ->
         pass = goodpass
         token = null
         login.__set__
            console:
               log: (m) ->
                  token = m
               warn: console.warn
         login.__set__ 'process.exit', (n) ->
            assert.equal n, 0, 'wrong return code'
            assert.equal token, goodToken, 'Bad token'
            done()
         login.__set__ 'process.env.TEST_TOKEN', badToken
         login.__set__ 'process.argv', ['node', 'ddp-login', '--env', 'TEST_TOKEN']
         login._command_line()

      it 'should retry 5 times by default', (done) ->
         pass = badpass
         token = null
         sinon.spy DDP.prototype, 'loginWithEmail'
         login.__set__
            console:
               log: (m) ->
                  token = m
               error: (m) ->
               warn: console.warn
               dir: (o) ->
         login.__set__ 'process.exit', (n) ->
            assert.equal n, 1
            assert.equal DDP.prototype.loginWithEmail.callCount, 5
            DDP.prototype.loginWithEmail.restore()
            done()
         login.__set__ 'process.env.TEST_TOKEN', badToken
         login.__set__ 'process.argv', ['node', 'ddp-login', '--env', 'TEST_TOKEN']
         login._command_line()

      it 'should retry the specified number of times', (done) ->
         pass = badpass
         token = null
         sinon.spy DDP.prototype, 'loginWithEmail'
         login.__set__
            console:
               log: (m) ->
                  token = m
               error: (m) ->
               warn: console.warn
               dir: (o) ->
         login.__set__ 'process.exit', (n) ->
            assert.equal n, 1
            assert.equal DDP.prototype.loginWithEmail.callCount, 3
            DDP.prototype.loginWithEmail.restore()
            done()
         login.__set__ 'process.env.TEST_TOKEN', badToken
         login.__set__ 'process.argv', ['node', 'ddp-login', '--env', 'TEST_TOKEN', '--retry', '3']
         login._command_line()

      afterEach () ->
         pass = null
