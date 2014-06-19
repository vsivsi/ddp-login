ddp-login
====================================

ddp-login is a node.js npm package providing a simple way to authenticate with a [Meteor](https://www.meteor.com/) server programmatically (as opposed to from within a browser) using the [DDP protocol](https://github.com/meteor/meteor/blob/master/packages/livedata/DDP.md). It provides both a Javascript API and a command-line tool that can be used within your favorite shell.

ddp-login is built on top of the [ddp](https://www.npmjs.org/package/ddp) npm package and makes it easy to prompt a user for login credentials (based on e-mail or username), authenticate a DDP connection and then securely cache the resulting authentication token in the process environment. If a valid token is already present in the environment, then there is no need to prompt the user and reauthentication occurs transparently.

**NOTE:** As of Meteor v0.8.2, the Meteor account database and authentication methods have changed significantly. You can read more about the changes [here](https://github.com/meteor/meteor/blob/release-0.8.2/History.md#meteor-accounts). These changes have brought some potential compatibility issues:
* As of ddp-login 1.0.0, authenticating with a Meteor server older than v0.8.2 requires the `plaintext` option.
* For servers v0.8.2 or newer, accounts created on older versions of Meteor need to be authenticated at least once using a Meteor client to transition the account to the new format
     * Until this is done, logging into these legacy accounts on a newer server using ddp-login will require the use of the `plaintext` option.
* For as long as you are only using pre-v0.8.2 servers, you may want to continue to use ddp-login v0.1.1, which will continue to fully support the old account types and SRP based login protocol.

The `plaintext` fallback is insecure on the wire (when not using SSL encryption), which is why it is not on by default. The new default remote login scheme for Meteor transmits the SHA256 digest of the password, which is more secure for strong passwords, but it still vulnerable to replay attacks. For these reasons, it is strongly advised that you use SSL encrypted DDP connections for all authentication requests that traverse untrusted networks.

## Installation

```bash
# For programmatic use in a node.js program:
npm install ddp-login

# For use in shell scripts (may require sudo)
npm -g install ddp-login

# From within a node_modules/ddp-test directory, unit tests may be run
npm test
```

## Usage

ddp-login currently supports three of Meteor's login methods:
* `'email'` -- email + password
* `'username'` -- username + password
* `'token'` -- authentication token from previous successful login

Note that all login methods will try to use an existing authentication token from the environment before falling back to the provided (or default) method. The 'token' method is used when no user intervention is possible and it is assumed that a valid token is present; in this case the login will either succeed or fail, without any user promting.

There are two possible ways to use this package:

### In node.js

If you'd like to log in and obtain an authentication token from a Meteor server within a node.js program:

```js
var DDP = require('ddp');
var login = require('ddp-login');

var ddpClient = new DDP({
  host: "localhost",
  port: 3000
});

// Options below are the defaults
login(ddpClient,
  {
     env: 'METEOR_TOKEN',  // Name of an environment variable to check for a
                           // token. If a token is found and is good,
                           // authentication will require no user interaction.
     method: 'email',      // Login method: email, username or token
     retry: 5,             // Number of login attempts to make
     plaintext: false      // Do not fallback to plaintext password compatibility
  },
  function (error, token) {
    if (error) {
      // Something went wrong...
    } else {
      // We are now logged in, with token as our session resume auth token.
      // Note that this token can't directly enter the parent process
      // environment, but it can be passed to any spawned child processes.
    }
  }
);
```

### From the command shell

Here's how to securely set an environment variable with an authentication token that can be used by other programs to avoid a user having to repeatedly enter credentials at the shell.

```bash
# Create an environment variable containing a valid authToken,
# prompting for account credentials only if necessary.
export METEOR_TOKEN=$(ddp-login --host 127.0.0.1 \
                                --port 3000 \
                                --env METEOR_TOKEN \
                                --method email \
                                --retry 5)

## Get command line help
ddp-login --help
```
The above will only work if `ddp-login` was installed with the `npm -g` option, or if it is run directly using node.js.

