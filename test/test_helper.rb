# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "statesman_scaffold"
require "statesman"
require "active_record"
require "minitest/autorun"

# ---------------------------------------------------------------------------
# In-memory SQLite database for ActiveRecord tests
# ---------------------------------------------------------------------------
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

# Silence ActiveRecord migration output in test runs
ActiveRecord::Migration.verbose = false

# ---------------------------------------------------------------------------
# Configure Statesman to use the ActiveRecord adapter, exactly as it would
# be in a Rails app after running `rails statesman_scaffold:install`.
# ---------------------------------------------------------------------------
Statesman.configure { storage_adapter(Statesman::Adapters::ActiveRecord) }

# ---------------------------------------------------------------------------
# Simulate the Rails initializer so AR models pick up the concern
# automatically, exactly as they would in a Rails app.
# ---------------------------------------------------------------------------
ActiveSupport.on_load(:active_record) do
  include StatesmanScaffold::Concern
end
