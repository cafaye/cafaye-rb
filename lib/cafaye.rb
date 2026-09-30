# frozen_string_literal: true

require "cafaye/version"
require "cafaye/errors"
require "cafaye/principal"
require "cafaye/token"
require "cafaye/jwks/key_set"
require "cafaye/jwks/transport"
require "cafaye/jwks/fetcher"
require "cafaye/jwks/cache"
require "cafaye/token_verifier"
require "cafaye/outbox"

# The shared Ruby library every cafaye Ruby service depends on, so that no
# service hand-rolls token verification or the outbox insert.
#
# Two things, both of which are a security incident waiting to be hand-written:
#
#   Cafaye::TokenVerifier — RS256 bearer tokens verified against identity's
#     published JWKS, with the algorithm allowlisted, the key set cached, and
#     the result frozen and explicit. Nothing it returns can carry the token, a
#     claim, or a key.
#
#   Cafaye::Outbox — core's event envelope, written into a Postgres outbox
#     inside the caller's own transaction, plus the loop that moves committed
#     rows to a transport.
#
# Both are inert until configured. Requiring this file installs nothing, opens
# nothing and connects to nothing, so an unconfigured service that has not
# called `Cafaye.configure` gets no error at boot and no behaviour at runtime —
# it is a library, not a framework that assumes it owns the process.
module Cafaye
  class << self
    # The library's logger. Every log line the library writes goes here, and the
    # canary test asserts over this sink, so a caller that swaps it in a test is
    # not exempt from the assertion.
    def logger
      @logger ||= default_logger
    end

    attr_writer :logger

    # The default sink is Ruby's stdlib logger on $stderr at WARN and above.
    #
    # Two reasons it is not a Rails logger: this gem must load in a non-Rails
    # service and in a plain script, and a library that reaches for its host's
    # logging framework at load time is a library that cannot be loaded before
    # the framework is configured. The Railtie points it at `Rails.logger` once
    # the host app is configured, which is the one moment it is safe to.
    #
    # Nothing at INFO or below is written by default, and there is nothing to
    # turn on. The library logs refusals and key-set failures and nothing else,
    # because the only two things a security library can usefully log are "a
    # request was refused, and why in the library's own vocabulary" and "I could
    # not reach a dependency". Everything a token carries is a secret by
    # construction, so there is no level at which it would be safe to print.
    def default_logger
      require "logger"
      logger = Logger.new($stderr)
      logger.level = Logger::WARN
      logger.formatter = ->(severity, _time, _progname, message) { "#{severity} cafaye: #{message}\n" }
      logger
    end

    # Test and development seam. `bin/prime` runs the suite in one process, and
    # a suite that cannot see the library's log output cannot assert on it.
    def reset!
      @logger = nil
    end
  end
end
