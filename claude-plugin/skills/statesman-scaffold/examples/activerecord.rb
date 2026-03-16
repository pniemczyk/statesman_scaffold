# frozen_string_literal: true

# Complete example: Project model with a 5-state machine
# Run: rails "statesman_scaffold:generate[Project]" then customise these files.

# ─── db/migrate/001_create_projects.rb ───────────────────────────────────────
class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name,   null: false
      t.string :status, default: "pending"
      t.timestamps
    end
  end
end

# ─── app/models/project/state_machine.rb ─────────────────────────────────────
class Project::StateMachine
  include Statesman::Machine

  state :pending,   initial: true
  state :active
  state :on_hold
  state :done
  state :cancelled

  transition from: :pending,  to: %i[active cancelled]
  transition from: :active,   to: %i[on_hold done cancelled]
  transition from: :on_hold,  to: %i[active cancelled]

  # Keep status column in sync (optional but recommended for fast reads)
  after_transition do |model, transition|
    model.update!(status: transition.to_state)
  end

  # Guard: cannot complete unless all tasks are done
  guard_transition(to: :done) do |project|
    project.tasks.incomplete.none?
  end

  # Callback: notify team when project goes on hold
  after_transition(to: :on_hold) do |project, transition|
    reason = transition.metadata["reason"]
    ProjectMailer.on_hold_notification(project, reason: reason).deliver_later
  end

  after_transition(to: :done) do |project, _transition|
    project.update!(completed_at: Time.current)
    ProjectMailer.completion_notification(project).deliver_later
  end
end

# ─── app/models/project/transition.rb (generated, no edits needed) ───────────
class Project::Transition < ApplicationRecord
  self.table_name = "project_transitions"

  belongs_to :project, class_name: "Project"

  attribute :most_recent, :boolean, default: false
  attribute :to_state, :string
  attribute :sort_key, :integer
  attribute :metadata, :json, default: {}

  validates :to_state, inclusion: { in: Project::StateMachine.states }
end

# ─── app/models/project.rb ───────────────────────────────────────────────────
class Project < ApplicationRecord
  STATUSES = Project::StateMachine.states

  with_state_machine

  attribute :status, :string, default: Project::StateMachine.initial_state

  validates :name,   presence: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  has_many :tasks, dependent: :destroy
end

# ─── Usage ────────────────────────────────────────────────────────────────────
project = Project.create!(name: "Alpha")

# Read state
project.current_state              # => "pending"
project.status                     # => "pending"

# Instance predicates
project.in_state?(:pending)        # => true
project.in_state?(:done, :pending) # => true  (matches any)
project.in_state?("pending")       # => true  (strings work)
project.not_in_state?(:done)       # => true

# Check if transition is allowed (checks rules AND guards)
project.can_transition_to?(:active)    # => true
project.can_transition_to?(:done)      # => false (not in allowed transitions from :pending)

# Transition (bang — raises on failure)
project.transition_to!(:active)
project.current_state              # => "active"
project.status                     # => "active" (synced by after_transition)

# Transition with metadata
project.transition_to!(:on_hold, metadata: { reason: "waiting_for_client" })

# Non-bang (returns true/false)
project.transition_to(:active)     # => true
project.transition_to(:pending)    # => false (not an allowed transition)

# Transition history
project.transitions.count          # => 2
project.transitions.last.to_state  # => "on_hold"
project.transitions.last.metadata  # => { "reason" => "waiting_for_client" }

# Class-level scopes
Project.in_state(:active)
Project.in_state(:active, :pending)
Project.not_in_state(:cancelled)
Project.where(owner: current_user).in_state(:active)
