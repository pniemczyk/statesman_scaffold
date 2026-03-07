# frozen_string_literal: true

require "test_helper"

# ---------------------------------------------------------------------------
# Named model classes used across concern tests.
# Defined in a module namespace to avoid constant pollution.
# ---------------------------------------------------------------------------
module SmTestModels
  class Project < ActiveRecord::Base
    self.table_name = "sm_projects"

    class StateMachine
      include Statesman::Machine

      state :active, initial: true
      state :pending
      state :skipped
      state :cancelled
      state :done

      transition from: :active, to: %i[pending skipped cancelled done]
      transition from: :pending, to: %i[skipped cancelled done]
      transition from: :skipped, to: [:pending]

      after_transition do |model, transition|
        model.update!(status: transition.to_state)
      end
    end

    class Transition < ActiveRecord::Base
      self.table_name = "sm_project_transitions"

      belongs_to :project, class_name: "SmTestModels::Project"

      attribute :most_recent, :boolean, default: false
      attribute :sort_key, :integer
      attribute :to_state, :string
      attribute :metadata, :json, default: {}

      validates :to_state, inclusion: { in: SmTestModels::Project::StateMachine.states }
    end

    STATUSES = %w[active pending done skipped cancelled].freeze

    with_state_machine

    attribute :name, :string
    attribute :status, :string, default: "active"

    validates :name, presence: true
    validates :status, inclusion: { in: STATUSES }, allow_nil: true
  end
end

module StatesmanScaffold
  class ConcernTest < Minitest::Test
    def setup
      create_projects_table
      create_project_transitions_table
    end

    def teardown
      conn.drop_table "sm_project_transitions"
      conn.drop_table "sm_projects"
    end

    # --- default state -------------------------------------------------------

    def test_starts_in_initial_state
      project = SmTestModels::Project.create!(name: "Test Project")

      assert_equal "active", project.current_state
    end

    def test_in_state_returns_true_for_current_state
      project = SmTestModels::Project.create!(name: "Test Project")

      assert project.in_state?(:active)
    end

    def test_in_state_returns_false_for_different_state
      project = SmTestModels::Project.create!(name: "Test Project")

      refute project.in_state?(:done)
    end

    def test_in_state_accepts_multiple_states
      project = SmTestModels::Project.create!(name: "Test Project")

      assert project.in_state?(:done, :active)
    end

    def test_not_in_state_returns_true_for_different_state
      project = SmTestModels::Project.create!(name: "Test Project")

      assert project.not_in_state?(:done)
    end

    def test_not_in_state_returns_false_for_current_state
      project = SmTestModels::Project.create!(name: "Test Project")

      refute project.not_in_state?(:active)
    end

    # --- transitions ---------------------------------------------------------

    def test_can_transition_to_valid_state
      project = SmTestModels::Project.create!(name: "Test Project")

      assert project.can_transition_to?(:pending)
    end

    def test_cannot_transition_to_invalid_state
      project = SmTestModels::Project.create!(name: "Test Project")

      refute project.can_transition_to?(:active)
    end

    def test_transition_to_changes_state
      project = SmTestModels::Project.create!(name: "Test Project")

      project.transition_to!(:pending)

      assert_equal "pending", project.current_state
    end

    def test_transition_to_updates_status_column
      project = SmTestModels::Project.create!(name: "Test Project")

      project.transition_to!(:pending)

      assert_equal "pending", project.status
    end

    def test_transition_to_invalid_state_raises
      project = SmTestModels::Project.create!(name: "Test Project")

      assert_raises(Statesman::TransitionFailedError) do
        project.transition_to!(:active)
      end
    end

    # --- transition records ---------------------------------------------------

    def test_records_transitions_in_database
      project = SmTestModels::Project.create!(name: "Test Project")

      project.transition_to!(:done)

      assert_equal 1, project.transitions.count
      assert_equal "done", project.transitions.last.to_state
    end

    def test_multiple_transitions_are_recorded
      project = SmTestModels::Project.create!(name: "Test Project")

      project.transition_to!(:pending)
      project.transition_to!(:done)

      assert_equal 2, project.transitions.count
    end

    # --- in_state? with string vs symbol -------------------------------------

    def test_in_state_works_with_string
      project = SmTestModels::Project.create!(name: "Test Project")

      assert project.in_state?("active")
    end

    # --- transition_to (non-bang) --------------------------------------------

    def test_transition_to_returns_true_on_success
      project = SmTestModels::Project.create!(name: "Test Project")

      assert project.transition_to(:pending)
    end

    def test_transition_to_returns_false_on_failure
      project = SmTestModels::Project.create!(name: "Test Project")

      refute project.transition_to(:active)
    end

    # --- has_many :transitions association ------------------------------------

    def test_transitions_association_exists
      project = SmTestModels::Project.create!(name: "Test Project")

      assert_respond_to project, :transitions
      assert_kind_of ActiveRecord::Associations::CollectionProxy, project.transitions
    end

    def test_destroying_model_destroys_transitions
      project = SmTestModels::Project.create!(name: "Test Project")
      project.transition_to!(:pending)

      assert_equal 1, SmTestModels::Project::Transition.count
      project.destroy!
      assert_equal 0, SmTestModels::Project::Transition.count
    end

    private

    def conn
      ActiveRecord::Base.connection
    end

    def create_projects_table
      conn.create_table "sm_projects", force: true do |t|
        t.string :name
        t.string :status, default: "active"
      end
    end

    def create_project_transitions_table
      conn.create_table "sm_project_transitions", force: true do |t|
        t.integer :project_id, null: false
        t.boolean :most_recent, default: false
        t.integer :sort_key
        t.string :to_state, null: false
        t.json :metadata
        t.timestamps null: false
      end
    end
  end
end
