# frozen_string_literal: true

require "erb"
require "pathname"

module StatesmanScaffold
  # Generates StateMachine, Transition class files, and a migration from ERB
  # templates. This class is intentionally decoupled from Rails so it can be
  # tested without booting a full Rails application.
  #
  # @example
  #   StatesmanScaffold::Generator.call(
  #     model: "Project",
  #     output_path: Pathname.new("app/models/project"),
  #     migration_path: Pathname.new("db/migrate"),
  #     migration_version: "8.0"
  #   )
  class Generator
    TEMPLATE_DIR = Pathname.new(__dir__).join("..", "templates", "statesman").expand_path

    Result = Struct.new(:state_machine_path, :transition_path, :migration_path, keyword_init: true) # rubocop:disable Style/RedundantStructKeywordInit

    class << self
      # Generate all three files for the given model.
      #
      # @param model [String] PascalCase model name (e.g. "Project", "Admin::Order")
      # @param output_path [Pathname, String] directory for model files
      # @param migration_path [Pathname, String] directory for migration file
      # @param migration_version [String] ActiveRecord migration version (e.g. "8.0")
      # @param timestamp [String, nil] migration timestamp (default: current UTC)
      # @return [Result] paths of created files
      def call(model:, output_path:, migration_path:, migration_version:, timestamp: nil)
        model       = model.to_s.camelize
        class_name  = model
        output_path = Pathname(output_path)
        migration_path = Pathname(migration_path)
        timestamp ||= Time.now.utc.strftime("%Y%m%d%H%M%S")

        output_path.mkpath
        migration_path.mkpath

        sm_path = render_template(
          "state_machine.rb.erb",
          output_path.join("state_machine.rb"),
          model: model, class_name: class_name
        )

        tr_path = render_template(
          "transition.rb.erb",
          output_path.join("transition.rb"),
          model: model, class_name: class_name
        )

        file_path = model.underscore.tr("/", "_")
        mig_file = "#{timestamp}_create_#{file_path}_transitions.rb"
        mig_path = render_template(
          "migration.rb.erb",
          migration_path.join(mig_file),
          model: model, class_name: class_name, version: migration_version
        )

        Result.new(
          state_machine_path: sm_path,
          transition_path: tr_path,
          migration_path: mig_path
        )
      end

      private

      def render_template(template_name, output_file, **locals)
        template_path = TEMPLATE_DIR.join(template_name)
        erb = ERB.new(template_path.read, trim_mode: "-")
        content = erb.result_with_hash(locals)
        output_file.write(content)
        output_file
      end
    end
  end
end
