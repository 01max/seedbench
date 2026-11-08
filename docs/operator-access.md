# Operator access

Seedbench has one operator account and no public registration. Passwords use
bcrypt hashing. Successful login rotates the Rails session and issues an
encrypted, HttpOnly, SameSite=Lax cookie with an opaque random token. Only its
SHA-256 digest is stored in the application database. The server expires each
login after 12 hours; logout revokes it immediately. HTTPS requests receive a
Secure cookie. Plain private-LAN HTTP remains the accepted transport limitation.

Application controllers require authentication by default. The login form and
the `/up` container health endpoint are public. Private responses prohibit
caching. Rails CSRF verification protects login, logout, and authenticated
state changes. A SQLite-backed limit permits ten login attempts per client IP
in a fifteen-minute window and survives process/container replacement. Stored
throttle identifiers are hashes, and old windows are pruned.

Authentication services handle password verification, session creation,
resumption, revocation, and throttling. Controllers handle HTTP cookies and
redirects. Passwords and session tokens are filtered from request parameters.

After `bin/setup`, initialize the operator password from the checkout on the
Docker host:

```sh
bin/operator-password
```

The same command resets a forgotten password. It uses the selected deployment's
Compose configuration and state volume, works with `SEEDBENCH_COMPOSE_ENV` and
Compose overrides, and starts a temporary web-image container without starting
the worker. No SSH alias, host Ruby, fixed mount point, or running web container
is required. An interactive terminal is required. Enter the new password twice;
input echo is disabled. Use at least 12 characters and at most 72 bytes.

Never put a password in command arguments, shell history, or environment
variables. The command accepts no arguments and prints only prompts and the
result. A successful reset atomically replaces the password hash, revokes all
existing login sessions, and clears login throttles. Invalid input preserves
the current password and sessions. Restarting containers alone does not reset
the account or its sessions.

These boundaries follow the [Rails security guide](https://guides.rubyonrails.org/security.html).
