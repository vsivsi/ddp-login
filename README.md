ddp-login
====================================

[![Build Status](https://travis-ci.org/vsivsi/ddp-login.svg)](https://travis-ci.org/vsivsi/ddp-login)

ddp-login is a node.js npm package providing a simple way to authenticate with a [Meteor](https://www.meteor.com/) server programmatically (as opposed to from within a browser) using the [DDP protocol](https://github.com/meteor/meteor/blob/devel/packages/ddp/DDP.md). It provides both a Javascript API and a command-line tool that can be used from within your favorite shell.

ddp-login is built on top of the [ddp](https://www.npmjs.org/package/ddp) npm package and makes it easy to prompt a user for login credentials (based on e-mail or username), authenticate a DDP connection and then securely cache the resulting authentication token in the process environment. If a valid token is already present in the environment, then there is no need to prompt the user and reauthentication occurs transparently. Alternatively, the Javascript API may provide account credentials to avoid unwanted user prompts.

## Security

The current secure remote login scheme for Meteor transmits the [SHA256 digest](https://en.wikipedia.org/wiki/SHA256) of the user's password, which is somewhat more secure than plaintext for strong passwords, however this approach is still vulnerable to replay attacks. For these reasons, it is strongly advised that you use SSL encrypted DDP connections for all authentication requests that traverse untrusted networks.

## Installation

```bash
# For programmatic use in a node.js program:
npm install ddp-login

# For use in shell scripts (may require sudo)
npm -g install ddp-login

# From within a node_modules/ddp-test directory, unit tests may be run
npm test

# To install ddp-login for the old pre-0.8.2 Meteor SRP style authentication:
npm install ddp-login@SRP
# or
npm -g install ddp-login@SRP
# See note at end of this README for more info!
```

## Usage

ddp-login currently supports the following login methods:
* `'email'` -- email + password
* `'username'` -- username + password
* `'account'` -- email or username + password. This method tries the `'email'` method first when the provided account looks like an email address. If that fails, or if the account doesn't look like an email address, then the `'username'` method is tried
* `'token'` -- authentication token from previous successful login

Note that all login methods will try to use an existing authentication token from the environment before falling back to the provided (or default) method. The 'token' method is used when no user intervention is possible and it is assumed that a valid token is present; in this case the login will either succeed or fail, without any user prompting.

There are two possible ways to use this package:

### From the command shell

Here's how to securely set an environment variable with an authentication token that can be used by other programs to avoid a user having to repeatedly enter credentials at the shell.

```bash
# Create an environment variable containing a valid authToken,
# prompting for account credentials only if necessary.
export METEOR_TOKEN=$(ddp-login --host 127.0.0.1 \
                                --port 3000 \
                                --env METEOR_TOKEN \
                                --method account \
                                --retry 5)

## Get full command line help for all options:
ddp-login --help
```
The above will only work if `ddp-login` was installed with the `npm -g` option, or if it is run directly using node.js.

Note: for security reasons, there is no way to pass the account credentials on the command line, as such credentials would be visible to all users of a machine in the process status.

### In node.js

If you'd like to log in to a Meteor server from within a node.js program, prompting the user for account credentials:

```js
var DDP = require('ddp');
var login = require('ddp-login');

var ddpClient = new DDP({
  host: "localhost",
  port: 3000
});

ddpClient.connect(function (err) {
  if (err) throw err;

  login(ddpClient,
    {  // Options below are the defaults
       env: 'METEOR_TOKEN',  // Name of an environment variable to check for a
                             // token. If a token is found and is good,
                             // authentication will require no user interaction.
       method: 'account',    // Login method: account, email, username or token
       account: null,        // Prompt for account info by default
       pass: null,           // Prompt for password by default
       retry: 5,             // Number of login attempts to make
       plaintext: false      // Do not fallback to plaintext password compatibility
                             // for older non-bcrypt accounts
    },
    function (error, userInfo) {
      if (error) {
        // Something went wrong...
      } else {
        // We are now logged in, with userInfo.token as our session auth token.
        token = userInfo.token;
      }
    }
  );
});

```

Providing values to the `account` and/or `pass` options will use those values instead of prompting the user.

`ddp-login` also supports the classic login methods from `node-ddp-client`. Note that these will only work for a Meteor v0.8.2 or later server with accounts that use the new bcrypt account scheme. Bcrypt account records are generated automatically for new accounts created on servers v0.8.2 or later, or for older accounts that have been authenticated at least once using the Meteor `accounts-password` client.

```js
var DDP = require('ddp');
var login = require('ddp-login');

token = null;

// Assume connected ddpClient, see above...

// Resume login with valid token from previous login
login.loginWithToken(ddpClient, token, function (err, userInfo) {
  if (err) throw err;
  token = userInfo.token;
});

// Login using a username
login.loginWithUsername(ddpClient, user, pass, function (err, userInfo) {
  if (err) throw err;
  token = userInfo.token;
});

// Login using an email address
login.loginWithEmail(ddpClient, email, pass, function (err, userInfo) {
  if (err) throw err;
  token = userInfo.token;
});

// Login using either a username or email address
login.loginWithAccount(ddpClient, userOrEmail, pass, function (err, userInfo) {
  if (err) throw err;
  token = userInfo.token;
});
```

## Note about compatibility with pre-0.8.2 versions of Meteor

As of Meteor v0.8.2, the Meteor account database and authentication methods have [changed significantly](https://github.com/meteor/meteor/blob/master/History.md#meteor-accounts-3). These changes have brought some potential compatibility issues:
* As of ddp-login v1.0.0, authenticating with a Meteor server older than v0.8.2 requires the `plaintext` option.
* For servers v0.8.2 or newer, accounts created on older versions of Meteor will be automatically migrated to the new "BCrypt" account type on first login (either using the Meteor Client or this package.)
* As long as you are only using pre-v0.8.2 servers, you may want to continue to use ddp-login v0.1.x, (available from npm using `ddp-login@SRP`) which will continue to fully support the old account types and SRP based login protocol.

The `plaintext` fallback is insecure on the wire (when not using SSL encryption), which is why it is not enabled by default.
