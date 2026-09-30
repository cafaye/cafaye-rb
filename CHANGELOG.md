# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Pre-1.0: a minor bump may break the API. Every break is listed here with the
commit that caused it and the one line that changes to opt back in.

## [Unreleased]

## [0.1.0] — 2026-09-30

The first real packet in a repository that was an empty scaffold. Three
deliverables, in the order they landed.

### Added

- **`Cafaye::TokenVerifier`** — RS256 verification against identity's JWKS at
  `{issuer}/.well-known/jwks.json`. The algorithm is an allowlist and `none`,
  HS256 and every symmetric algorithm are refused from the protected header
  before any key is fetched, so an attacker cannot aim an outbound request at
  identity by choosing an algorithm. `iss`, `aud`, `exp`, `iat`, `nbf` and `sub`
  are checked; `jti` is required, per core's
  `docs/openapi-conventions.md`.
- **A bounded key-set cache** — one fetch per TTL, **one** forced refresh per
  minimum interval for an unknown `kid`, and a negative cache for unknown `kid`s
  that is itself size-capped. A caller who sends a request per bad token buys a
  refusal per bad token, not an outbound request.
- **`Cafaye::Principal`** — the verified caller, frozen, with named readers for
  the subject, the account, the scopes, the expiry and the token id. It has no
  `[]`, no `to_h` of the claims hash, and no accessor that can reach a claim
  this library did not name.
- **The canary test** — a unique string in a claim, asserted *present* in the
  input first and then asserted absent from every log line at every level, from
  every exception message, and from every backtrace. `Cafaye::Token` is a string
  that will not print itself, so `%s` and f-strings cannot leak one.
- **`Cafaye::Outbox`** — `publish!` writes core's event envelope into
  `outbox_events` on the caller's connection and **refuses to write outside a
  transaction**. The envelope `id` is a UUID minted per emission and reused on
  every retry of that row, which is what makes at-least-once safe for a consumer
  deduping on it.
- **`Cafaye::Outbox::Publisher`** — claims a batch with `for update skip locked`,
  delivers in `created_at` order, and marks `published_at` only on the
  transport's acknowledgement. Failures increment `attempts` and back off.
- **`db/outbox_events.sql`** — core's column list, plus the CHECK constraints
  from core's envelope schema, as the one file both this gem's suite and a
  service's own migration are built from.
- **`Cafaye::Railtie`** — installs both halves into a host app and generates the
  outbox migration. Inert until `Cafaye.configure` is called: an unconfigured
  app that raises at boot is a worse failure than one that does nothing.
- **`cafaye.yml`**, `AGENTS.md`, `.rubocop.yml`, `mise.toml`, `bin/prime` and
  `.github/workflows/ci.yml`.

### Open decisions

Recorded in full in `cafaye.yml` and in the worker report. The two that change
the API's shape:

1. **The claim contract is ambiguous.** core says `scopes` (an array, required)
   and `account_id`; `guard` reads `scope` (a space-separated string,
   optional) and no tenant claim at all; `identity` mints no tokens yet, so
   there is nothing to read the names off. This gem reads both scope claim
   names, makes the account claim opt-in, and matches guard on RS256-only. One
   constant each to flip: `Cafaye::TokenVerifier::DEFAULT_SCOPE_CLAIMS`,
   `Cafaye.config.account_claim`, `ALGORITHMS`.
2. **`core/docs/event-outbox.md` says there is no shared outbox library.** This
   repository is one. Reconcilable — this gem speaks SQL over one connection
   and owns no ORM — but core is read-only from here, so the contradiction
   stands in the document.

[Unreleased]: https://github.com/cafaye/cafaye-rb/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/cafaye/cafaye-rb/releases/tag/v0.1.0
