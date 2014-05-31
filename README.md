ddp-login
====================================

ddp-login makes it super easy to programmaticly authenticate with [Meteor](https://www.meteor.com/) server using the [DDP protocol](https://github.com/meteor/meteor/blob/master/packages/livedata/DDP.md).

It is an node.js npm package built on top of the [ddp](https://www.npmjs.org/package/ddp) package.

## Installation

```
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
     env: 'METEOR_TOKEN',  // Name of an environment variable to check for a good token
                           // If a token is found and is good, authentication will require no
                           // user interaction.
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

```
export METEOR_TOKEN=$(ddp-login --host 127.0.0.1 --port 3000 --env METEOR_TOKEN --method email)
```
The above will only work if `ddp-login` was installed with the `npm -g` option, or if it is run directly using node.js.


