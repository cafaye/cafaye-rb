# cafaye

The shared Ruby library every cafaye Ruby service depends on, so that no service
hand-rolls token verification or the outbox insert.

It is two things, and both of them are a security incident waiting to be
hand-written:

- **JWKS-backed token verification** — RS256 bearer tokens checked against
  identity's published key set, with the algorithm allowlisted, the key set
  cached and the refresh bounded, and a frozen result that cannot carry the
  token, a claim or a key.
- **A transactional outbox writer** — core's event envelope written into a
  Postgres outbox *inside the caller's own transaction*, plus the loop that
  moves committed rows to a transport.

## Install

```ruby
# Gemfile
gem "cafaye"
```

## Use

See [README.md](README.md) for a worked example that runs, and
[AGENTS.md](AGENTS.md) for the rules a change here is held to.

## The gate

```sh
mise install     # once per clone
bin/prime        # bundle, database, rubocop, bundler-audit, minitest
```

`bin/prime` creates its own test database from the same reference DDL the gem
ships to services, so a clean checkout primes with no manual step. Point it
somewhere else with `CAFAYE_TEST_DATABASE_URL`.
