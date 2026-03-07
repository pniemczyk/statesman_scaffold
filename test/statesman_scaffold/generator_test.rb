# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

module StatesmanScaffold
  class GeneratorTest < Minitest::Test
    def setup
      @tmpdir = Dir.mktmpdir("statesman_scaffold_generator_test")
      @root   = Pathname.new(@tmpdir)
      @output_path = @root.join("app/models/project")
      @migration_path = @root.join("db/migrate")
    end

    def teardown
      FileUtils.rm_rf(@tmpdir)
    end

    # --- file creation -------------------------------------------------------

    def test_creates_state_machine_file
      result = generate("Project")

      assert_predicate result.state_machine_path, :exist?
    end

    def test_creates_transition_file
      result = generate("Project")

      assert_predicate result.transition_path, :exist?
    end

    def test_creates_migration_file
      result = generate("Project")

      assert_predicate result.migration_path, :exist?
    end

    def test_creates_output_directory_if_missing
      refute_predicate @output_path, :exist?

      generate("Project")

      assert_predicate @output_path, :exist?
    end

    def test_creates_migration_directory_if_missing
      refute_predicate @migration_path, :exist?

      generate("Project")

      assert_predicate @migration_path, :exist?
    end

    # --- state machine file content ------------------------------------------

    def test_state_machine_contains_class_name
      result = generate("Project")

      content = result.state_machine_path.read
      assert_includes content, "class Project::StateMachine"
    end

    def test_state_machine_includes_statesman_machine
      result = generate("Project")

      content = result.state_machine_path.read
      assert_includes content, "include Statesman::Machine"
    end

    def test_state_machine_has_initial_state
      result = generate("Project")

      content = result.state_machine_path.read
      assert_includes content, "state :pending, initial: true"
    end

    # --- transition file content ---------------------------------------------

    def test_transition_contains_class_name
      result = generate("Project")

      content = result.transition_path.read
      assert_includes content, "class Project::Transition"
    end

    def test_transition_belongs_to_model
      result = generate("Project")

      content = result.transition_path.read
      assert_includes content, 'belongs_to :project, class_name: "Project"'
    end

    def test_transition_validates_to_state
      result = generate("Project")

      content = result.transition_path.read
      assert_includes content, "validates :to_state, inclusion: { in: Project::StateMachine.states }"
    end

    def test_transition_has_table_name
      result = generate("Project")

      content = result.transition_path.read
      assert_includes content, 'self.table_name = "project_transitions"'
    end

    # --- migration file content ----------------------------------------------

    def test_migration_contains_class_name
      result = generate("Project")

      content = result.migration_path.read
      assert_includes content, "class CreateProjectTransitions"
    end

    def test_migration_creates_transitions_table
      result = generate("Project")

      content = result.migration_path.read
      assert_includes content, "create_table :project_transitions"
    end

    def test_migration_has_correct_version
      result = generate("Project")

      content = result.migration_path.read
      assert_includes content, "ActiveRecord::Migration[8.0]"
    end

    def test_migration_has_indexes
      result = generate("Project")

      content = result.migration_path.read
      assert_includes content, "index_project_transition_parent_sort"
      assert_includes content, "index_project_transition_parent_most_recent"
    end

    def test_migration_filename_contains_timestamp
      result = generate("Project", timestamp: "20260307120000")

      assert_includes result.migration_path.basename.to_s, "20260307120000_create_project_transitions.rb"
    end

    # --- namespaced models ---------------------------------------------------

    def test_namespaced_model_state_machine
      result = generate("Admin::Order", output_path: @root.join("app/models/admin/order"))

      content = result.state_machine_path.read
      assert_includes content, "class Admin::Order::StateMachine"
    end

    def test_namespaced_model_transition
      result = generate("Admin::Order", output_path: @root.join("app/models/admin/order"))

      content = result.transition_path.read
      assert_includes content, "class Admin::Order::Transition"
      assert_includes content, 'belongs_to :order, class_name: "Admin::Order"'
      assert_includes content, 'self.table_name = "admin_order_transitions"'
    end

    def test_namespaced_model_migration
      result = generate("Admin::Order", output_path: @root.join("app/models/admin/order"))

      content = result.migration_path.read
      assert_includes content, "class CreateAdminOrderTransitions"
      assert_includes content, "create_table :admin_order_transitions"
      assert_includes content, "foreign_key: { to_table: :admin_orders }"
    end

    # --- result struct -------------------------------------------------------

    def test_result_is_a_struct
      result = generate("Project")

      assert_respond_to result, :state_machine_path
      assert_respond_to result, :transition_path
      assert_respond_to result, :migration_path
    end

    # --- template directory --------------------------------------------------

    def test_template_dir_exists
      assert_predicate Generator::TEMPLATE_DIR, :exist?
    end

    # --- generated files are valid Ruby --------------------------------------

    def test_state_machine_is_valid_ruby
      result = generate("Project")

      assert_valid_ruby result.state_machine_path
    end

    def test_transition_is_valid_ruby
      result = generate("Project")

      assert_valid_ruby result.transition_path
    end

    def test_migration_is_valid_ruby
      result = generate("Project")

      assert_valid_ruby result.migration_path
    end

    private

    def generate(model, output_path: @output_path, timestamp: nil)
      Generator.call(
        model: model,
        output_path: output_path,
        migration_path: @migration_path,
        migration_version: "8.0",
        timestamp: timestamp
      )
    end

    def assert_valid_ruby(path)
      result = `ruby -c #{path} 2>&1`
      assert_includes result, "Syntax OK", "Expected valid Ruby in #{path.basename}: #{result}"
    end
  end
end
