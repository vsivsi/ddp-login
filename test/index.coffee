# Unit tests

assert = require 'assert'
rewire = require 'rewire'
sinon = require 'sinon'
# ddp = require 'ddp'

login = rewire '../src/index.coffee'

describe 'login API', () ->

   goodToken = 'Ge1KTcEL8MbPc7hq_M5OkOwKHtNzbCdiDqaEoUNux22'
   badToken =  'slkf90sfj3fls9j930fjfssjf9jf3fjs_fssh82344f'

   user = 'bozo'
   email = 'bozo@clowns.com'
   goodpass = 'secure'
   badpass = 'insecure'
   pass = null

   before () ->
      console.dir login.__get__('read')
      login.__set__ 'read', (obj, cb) ->
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

   ddp =
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