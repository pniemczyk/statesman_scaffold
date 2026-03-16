# frozen_string_literal: true

# Testing patterns for models that use statesman_scaffold.
# All examples use Minitest (Rails default).

# ─── test/models/project_test.rb ─────────────────────────────────────────────
class ProjectTest < ActiveSupport::TestCase
  # ── initial state ──────────────────────────────────────────────────────────
  test "starts in pending state" do
    project = Project.create!(name: "Test")
    assert_equal "pending", project.current_state
    assert_equal "pending", project.status
    assert project.in_state?(:pending)
    refute project.in_state?(:active)
  end

  # ── transition_to! ─────────────────────────────────────────────────────────
  test "transitions from pending to active" do
    project = Project.create!(name: "Test")
    assert project.can_transition_to?(:active)
    project.transition_to!(:active)
    assert_equal "active", project.current_state
    assert_equal "active", project.status
  end

  # ── invalid transitions ────────────────────────────────────────────────────
  test "cannot transition to an undefined state" do
    project = Project.create!(name: "Test")
    refute project.can_transition_to?(:nonexistent)
    assert_raises(Statesman::TransitionFailedError) do
      project.transition_to!(:nonexistent)
    end
  end

  test "cannot skip states" do
    project = Project.create!(name: "Test")
    # pending → done is not a defined transition
    refute project.can_transition_to?(:done)
    refute project.transition_to(:done)
  end

  # ── guard failures ─────────────────────────────────────────────────────────
  test "cannot transition to done when tasks are incomplete" do
    project = Project.create!(name: "Test")
    project.tasks.create!(title: "Open task", completed: false)
    project.transition_to!(:active)

    refute project.can_transition_to?(:done)
    assert_raises(Statesman::GuardFailedError) do
      project.transition_to!(:done)
    end
  end

  test "can transition to done when all tasks are complete" do
    project = Project.create!(name: "Test")
    project.tasks.create!(title: "Done task", completed: true)
    project.transition_to!(:active)

    assert project.can_transition_to?(:done)
    assert project.transition_to(:done)
  end

  # ── non-bang transition ────────────────────────────────────────────────────
  test "transition_to returns false on failure without raising" do
    project = Project.create!(name: "Test")
    result = project.transition_to(:done)  # pending → done not allowed
    assert_equal false, result
    assert_equal "pending", project.current_state
  end

  # ── in_state? / not_in_state? ──────────────────────────────────────────────
  test "in_state? matches multiple states" do
    project = Project.create!(name: "Test")
    assert project.in_state?(:pending, :active)
    refute project.in_state?(:done, :cancelled)
  end

  test "in_state? accepts strings" do
    project = Project.create!(name: "Test")
    assert project.in_state?("pending")
  end

  test "not_in_state? is the negation of in_state?" do
    project = Project.create!(name: "Test")
    assert project.not_in_state?(:active)
    refute project.not_in_state?(:pending)
  end

  # ── class-level scopes ────────────────────────────────────────────────────
  test ".in_state scope returns matching records" do
    pending_project = Project.create!(name: "Pending")
    active_project  = Project.create!(name: "Active")
    active_project.transition_to!(:active)

    assert_includes Project.in_state(:pending), pending_project
    refute_includes Project.in_state(:pending), active_project
    assert_includes Project.in_state(:active),  active_project
  end

  test ".not_in_state scope excludes matching records" do
    project = Project.create!(name: "Test")
    project.transition_to!(:active)

    refute_includes Project.not_in_state(:active), project
    assert_includes Project.not_in_state(:cancelled), project
  end

  # ── transition history ─────────────────────────────────────────────────────
  test "records transitions" do
    project = Project.create!(name: "Test")
    project.transition_to!(:active)
    project.transition_to!(:on_hold, metadata: { reason: "waiting" })

    assert_equal 2, project.transitions.count
    assert_equal "on_hold", project.transitions.last.to_state
    assert_equal "waiting", project.transitions.last.metadata["reason"]
  end

  test "destroys transitions when project is destroyed" do
    project = Project.create!(name: "Test")
    project.transition_to!(:active)
    project_id = project.id

    project.destroy!
    assert_equal 0, Project::Transition.where(project_id: project_id).count
  end

  # ── metadata ──────────────────────────────────────────────────────────────
  test "stores and retrieves metadata" do
    project = Project.create!(name: "Test")
    project.transition_to!(:active, metadata: { triggered_by: "user:42" })

    last = project.transitions.last
    assert_equal "user:42", last.metadata["triggered_by"]
  end
end

# ─── RSpec equivalent (for projects using RSpec) ─────────────────────────────
#
# RSpec.describe Project, type: :model do
#   subject(:project) { create(:project) }
#
#   describe '#current_state' do
#     it 'starts in pending' do
#       expect(project.current_state).to eq('pending')
#     end
#   end
#
#   describe '#transition_to!' do
#     context 'when transitioning to active' do
#       it 'succeeds' do
#         project.transition_to!(:active)
#         expect(project.current_state).to eq('active')
#       end
#     end
#
#     context 'when transition is not allowed' do
#       it 'raises TransitionFailedError' do
#         expect { project.transition_to!(:done) }
#           .to raise_error(Statesman::TransitionFailedError)
#       end
#     end
#   end
#
#   describe '.in_state' do
#     it 'returns only matching records' do
#       active = create(:project, :active)
#       pending = create(:project)
#       expect(Project.in_state(:active)).to include(active)
#       expect(Project.in_state(:active)).not_to include(pending)
#     end
#   end
# end
