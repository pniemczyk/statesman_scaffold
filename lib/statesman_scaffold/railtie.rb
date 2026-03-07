# frozen_string_literal: true

module StatesmanScaffold
  # Hooks StatesmanScaffold into a Rails application.
  #
  # When Rails loads, this Railtie exposes the +statesman_scaffold:install+,
  # +statesman_scaffold:uninstall+, and +statesman_scaffold:generate+ rake tasks.
  class Railtie < Rails::Railtie
    railtie_name :statesman_scaffold

    rake_tasks do
      load File.expand_path("../tasks/statesman_scaffold.rake", __dir__)
    end
  end
end
