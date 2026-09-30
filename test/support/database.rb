# frozen_string_literal: true

require "pg"
require "uri"

module TestSupport
  # The suite's PostgreSQL database: created if it is missing, and always the
  # gem's own reference DDL.
  #
  # It is a real database rather than a fake for one specific reason. The
  # contract this gem exists to provide is "the insert rolls back with the state
  # change". A fake that pretends to roll back would be testing the fake, and the
  # two things that make the outbox work — `for update skip locked` really
  # skipping a row another session holds, and an exception really discarding the
  # insert — are both properties of PostgreSQL rather than of this code.
  #
  # `bin/prime` runs `rake db:prepare`, which calls `prepare!`, so a clean
  # checkout primes without a manual step. CI sets CAFAYE_TEST_DATABASE_URL to
  # point at its own service.
  module Database
    DEFAULT_URL = "postgres://localhost/cafaye_test"
    DDL_PATH = File.expand_path("../../db/outbox_events.sql", __dir__)

    class Unreachable < StandardError; end

    module_function

    # The URL under test. `CAFAYE_TEST_DATABASE_URL` first, so a CI service or a
    # developer's own instance can be pointed at without editing a file.
    def url
      ENV.fetch("CAFAYE_TEST_DATABASE_URL", DEFAULT_URL)
    end

    # Creates the database when it does not exist and loads the schema. Safe to
    # run repeatedly: both halves are idempotent, because a prime that failed
    # halfway and then failed again for a different reason is worse than one that
    # repairs itself.
    def prepare!
      create_database!
      reset_schema!
      url
    end

    def create_database!
      name = database_name
      return if database_exists?(name)

      with_maintenance_connection do |connection|
        # `create_database` has no `if not exists` in PostgreSQL 15 and earlier,
        # and a race between two checkouts creating the same database is a race
        # the second one loses to an exception it can recognise. The duplicate
        # database error code is 42P04.
        connection.exec("create database #{connection.quote_ident(name)}")
      rescue PG::Error => error
        raise unless error.result&.error_field(PG::Result::PG_DIAG_SQLSTATE) == "42P04"

        nil
      end
      nil
    end

    def reset_schema!
      connection.exec("drop table if exists outbox_events")
      connection.exec(File.read(DDL_PATH))
    end

    def connection
      @connection ||= begin
        conn = PG::Connection.new(url)
        conn.exec("set client_min_messages to warning")
        conn
      rescue PG::Error => error
        raise Unreachable, "cannot reach the test database at #{url}: #{error.message.strip}"
      end
    end

    def with_connection
      yield connection
    end

    # Runs the block inside a transaction that is always rolled back, so a test
    # that writes rows does not have to clean up and two tests cannot see each
    # other's rows.
    #
    # A test that asserts a rollback raises inside the block, and the raise
    # propagates out through here: the inner transaction is already gone, and
    # this one discards everything above it too. That is the real shape of the
    # case, so the test does not have to simulate it.
    def in_transaction
      connection.exec("begin")
      yield connection
      connection.exec("rollback")
    rescue StandardError, Minitest::Assertion
      connection.exec("rollback") if idle?
      raise
    end

    private_class_method def idle?
      connection.transaction_status == PG::PQTRANS_IDLE
    end

    private_class_method def with_maintenance_connection
      yield PG::Connection.new(maintenance_url)
    end

    # The database named in the URL, with a quote for the DSN. `postgres` is
    # always present on a working server and is the documented way to ask for
    # "the maintenance database".
    private_class_method def database_name
      url.split("/").last.to_s.split("?").first.to_s
    end

    private_class_method def maintenance_url
      uri = URI.parse(url)
      uri.path = "/postgres"
      uri.to_s
    end

    private_class_method def database_exists?(name)
      with_maintenance_connection do |connection|
        connection.exec_params("select 1 from pg_database where datname = $1", [ name ]).ntuples.positive?
      end
    end
  end
end
