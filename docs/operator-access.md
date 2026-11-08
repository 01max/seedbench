# Operator access

Seedbench uses Devise for its single operator, with no public registration,
email login, remember-me cookie, or browser password recovery. Devise owns
bcrypt password verification, login/logout, session rotation, account locking,
and inactivity timeouts. The password-only form always selects the one
database-constrained operator account; it cannot select or create another account.

Rails' Active Record session store retains JSON session data in the application
database. The HttpOnly, SameSite=Lax cookie contains an opaque session ID; the
database stores its private digest. Server-side lookups reject sessions older
than 12 hours even if they were recently active, and logout deletes the original
session so a copied cookie cannot restore it. Devise also enforces a twelve-hour
inactivity timeout. HTTPS requests receive a Secure cookie. Plain private-LAN
HTTP remains the accepted transport limitation.

Application controllers require authentication by default. The login form and
the `/up` container health endpoint are public. Private responses prohibit
caching. Rails CSRF verification protects login, logout, and authenticated
state changes. Devise's `lockable` module locks the operator account after ten
failed attempts and unlocks it after fifteen minutes. Failed attempts and the
lock timestamp persist in SQLite across process/container replacement. The lock
applies to every client, regardless of address or forwarding headers. Successful
login clears the failed-attempt count; locked accounts receive the same generic
rejection as an incorrect password. The terminal reset command also unlocks the
account.

The Devise session controller adds explicit CSRF verification. The application
uses Devise's authentication guard and current-operator helpers. Passwords and session identifiers are filtered from
request parameters. Expired session rows can be removed with the session store's
`db:sessions:trim` task; schedule it periodically for long-lived deployments.

Upgrading preserves the existing bcrypt password hash under Devise's
`encrypted_password` column. Old custom login cookies are invalidated, so sign
in again after migration. Provider credentials, encryption keys, releases, and
their assignments are preserved.

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
existing login sessions, and clears the account lock. Invalid input preserves
the current password and sessions. Restarting containers alone does not reset
the account or its sessions.

Implementation references: [Devise](https://github.com/heartcombo/devise),
[Rails Active Record session store](https://github.com/rails/activerecord-session_store),
and the [Rails security guide](https://guides.rubyonrails.org/security.html).
