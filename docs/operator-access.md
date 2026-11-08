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

These boundaries follow the [Rails security guide](https://guides.rubyonrails.org/security.html).
