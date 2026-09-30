source "https://rubygems.org"

# The gem's own runtime dependencies. Exactly two, and each one owns a contract
# this repository would otherwise be hand-rolling in the one place a mistake is a
# security incident.
#
# `jwt` owns JSON Web Token parsing, JWK import, and RSASSA-PKCS1-v1_5
# signature verification. That is a crypto path: base64url decoding, DER to
# key material, PKCS#1 v1.5 padding and the constant-time comparison a
# verification ends in. Writing it here would mean writing a verifier nobody
# audits, in a gem every Ruby service in the fleet depends on, on the code path
# that decides who is allowed to call billing. The gem is also the
# algorithm-confusion defence — `alg` comes from the token, and the only safe
# answer to that is a library that takes the allowlist as a required argument.
gem "jwt", "~> 3.1"

# `pg` owns the PostgreSQL wire protocol. The outbox is a Postgres table by
# decision (core's docs/event-outbox.md, courier's Oban, database-per-service),
# and the writer has to issue `insert ... for update skip locked` on the *caller's*
# connection to enlist in the caller's transaction. Depending on Active Record
# instead would make a non-Rails service inherit an ORM to move one row, and
# would make the transactional guarantee untestable outside Rails.
gem "pg", "~> 1.5"

group :development, :test do
  gem "minitest", "~> 6.0"
  gem "rake", "~> 13.3"

  # Active Record and Railties are *development* dependencies, not runtime ones.
  # They are here so the two adapters this gem ships — the one that speaks to an
  # AR connection and the Railtie that installs both halves into a host app — are
  # tested against the real thing rather than against a description of it. The
  # gem declares them as optional runtime dependencies in the gemspec, so a
  # service that does not use Rails never installs them.
  gem "activerecord", "~> 8.1"
  gem "railties", "~> 8.1"

  # House style, the same omakase rules billing lints with, so a service can add
  # this gem without a second RuboCop configuration in the repository.
  gem "rubocop-rails-omakase", require: false

  # Audits gems for known security defects. A shared library is the one place a
  # CVE in a transitive dependency reaches every service at once, so the audit is
  # in `bin/prime` rather than in a CI-only job someone can forget to open.
  gem "bundler-audit", require: false
end
