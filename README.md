ddp-login
====================================

ddp-login is a node.js npm package providing a simple way to authenticate with a [Meteor](https://www.meteor.com/) server programmatically (as opposed to from within a browser) using the [DDP protocol](https://github.com/meteor/meteor/blob/master/packages/livedata/DDP.md).

ddp-login is built on top of the [ddp](https://www.npmjs.org/package/ddp) npm package and makes it easy to prompt a user for login credentials (e-mail or username bbased), authenticate a DDP connection and then securely cache those credentials in the process environment in the form of an authentication token. If a valid token is already present in the environment, then there is no need for user prompting and reauthentication occurs transparently.

## Installation

```bash
# For programmatic use in a node.js program:
npm install ddp-login

# For use in shell scripts
npm -g install ddp-login
```

## Usage

There are two possible ways to use this package.

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
     method: 'email'       // Login method: email or username
     retry: 5              // Number of login attempts to make
	},
  function (error, token) {
    if (error) {
      // Something went wrong...
    } else {
      // We are now logged in, with token as our session resume authToken...
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

# Get command line help
ddp-login --help
```
The above will only work if `ddp-login` was installed with the `npm -g` option, or if it is run directly using node.js.
