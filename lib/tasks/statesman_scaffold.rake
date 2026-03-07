# frozen_string_literal: true

STATESMAN_SCAFFOLD_INITIALIZER_PATH = StatesmanScaffold::Installer::INITIALIZER_PATH.to_s

namespace :statesman_scaffold do
  desc "Install the StatesmanScaffold initializer (Statesman AR adapter + auto-include concern)"
  task :install do
    result = StatesmanScaffold::Installer.install!(Rails.root)
    case result
    when :created then puts "  #{"create".ljust(10)} #{STATESMAN_SCAFFOLD_INITIALIZER_PATH}"
    when :skipped then puts "  #{"skip".ljust(10)} #{STATESMAN_SCAFFOLD_INITIALIZER_PATH} already exists"
    end
  end

  desc "Remove the StatesmanScaffold initializer"
  task :uninstall do
    result = StatesmanScaffold::Installer.uninstall!(Rails.root)
    case result
    when :removed then puts "  #{"remove".ljust(10)} #{STATESMAN_SCAFFOLD_INITIALIZER_PATH}"
    when :skipped then puts "  #{"skip".ljust(10)} #{STATESMAN_SCAFFOLD_INITIALIZER_PATH} not found"
    end
  end

  desc "Generate StateMachine, Transition class, and migration for a model"
  task :generate, [:model] => :environment do |_, args|
    model = args[:model].to_s.camelize
    abort "Model name required. Usage: rails \"statesman_scaffold:generate[ModelName]\"" if model.blank?

    file_path = model.underscore
    output_path = Rails.root.join("app/models", file_path)
    migration_path = Rails.root.join("db/migrate")
    version = ActiveRecord::Migration.current_version.to_s[0..2]

    result = StatesmanScaffold::Generator.call(
      model: model,
      output_path: output_path,
      migration_path: migration_path,
      migration_version: version
    )

    puts "  #{"create".ljust(10)} #{result.state_machine_path.relative_path_from(Rails.root)}"
    puts "  #{"create".ljust(10)} #{result.transition_path.relative_path_from(Rails.root)}"
    puts "  #{"create".ljust(10)} #{result.migration_path.relative_path_from(Rails.root)}"
    puts ""
    puts "Don't forget to update your #{model} model by adding:"
    puts ""
    puts "  include StatesmanScaffold::Concern"
    puts "  with_state_machine"
    puts ""
    puts "If you haven't already, run: rails statesman_scaffold:install"
  end
end
