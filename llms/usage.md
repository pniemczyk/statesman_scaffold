# StatesmanScaffold -- Usage Patterns for LLMs

> Concrete, copy-pasteable examples covering every supported scenario.
> Optimised for LLM code generation — each section is self-contained.

---

## 1. Installation

```bash
# Gemfile
gem "statesman"
gem "statesman_scaffold"

# Terminal
bundle install
rails statesman_scaffold:install   # creates config/initializers/statesman_scaffold.rb
```

The initializer auto-includes `StatesmanScaffold::Concern` into every
`ActiveRecord::Base` subclass and configures Statesman to use the ActiveRecord
adapter. No `include` is needed in individual models.

---

## 2. Generate state machine files

```bash
rails "statesman_scaffold:generate[Project]"
```

Creates three files:

```
app/models/project/state_machine.rb     # Project::StateMachine
app/models/project/transition.rb        # Project::Transition
db/migrate/TIMESTAMP_create_project_transitions.rb
```

Then run the migration:

```bash
rails db:migrate
```

---

## 3. Configure the StateMachine class

Edit the generated `app/models/project/state_machine.rb`:

```ruby
# frozen_string_literal: true

class Project::StateMachine
  include Statesman::Machine

  state :active, initial: true
  state :pending
  state :skipped
  state :cancelled
  state :done

  transition from: :active, to: %i[pending skipped cancelled done]
  transition from: :pending, to: %i[skipped cancelled done]
  transition from: :skipped, to: [:pending]

  # Sync the status column after every transition
  after_transition do |model, transition|
    model.update!(status: transition.to_state)
  end

  # Optional: guard transitions
  # guard_transition(to: :done) do |project|
  #   project.tasks_completed?
  # end

  # Optional: before/after hooks for specific transitions
  # after_transition(to: :done) do |project, transition|
  #   ProjectMailer.completed(project).deliver_later
  # end
end
```

---

## 4. Configure the model

```ruby
class Project < ApplicationRecord
  STATUSES = Project::StateMachine.states

  with_state_machine

  attribute :status, :string, default: Project::StateMachine.initial_state
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
end
```

The `with_state_machine` macro handles:
- `has_many :transitions` (with `dependent: :destroy`)
- `Statesman::Adapters::ActiveRecordQueries` (for `.in_state` / `.not_in_state` scopes)
- A `state_machine` instance method

---

## 5. Basic state machine usage

```ruby
project = Project.create!(name: "Demo")

# Check current state
project.current_state              # => "active"
project.status                     # => "active"

# Predicates
project.in_state?(:active)         # => true
project.in_state?(:done, :active)  # => true (matches any)
project.not_in_state?(:done)       # => true
project.in_state?("active")        # => true (strings work too)

# Check if transition is possible
project.can_transition_to?(:pending)  # => true
project.can_transition_to?(:active)   # => false (no self-transition)

# Transition (bang version — raises on failure)
project.transition_to!(:pending)
project.current_state              # => "pending"
project.status                     # => "pending" (synced by after_transition)

# Transition (non-bang version — returns true/false)
project.transition_to(:done)       # => true
project.transition_to(:active)     # => false (not allowed)
```

---

## 6. Query scopes

```ruby
# Class-level scopes from Statesman::Adapters::ActiveRecordQueries
Project.in_state(:active)
Project.in_state(:active, :pending)
Project.not_in_state(:cancelled)

# Combine with other AR scopes
Project.where(team: "Engineering").in_state(:active)
```

---

## 7. Transition history

```ruby
project = Project.create!(name: "Demo")
project.transition_to!(:pending)
project.transition_to!(:done)

# Access transition records
project.transitions                # => [#<Project::Transition ...>, ...]
project.transitions.count          # => 2
project.transitions.last.to_state  # => "done"

# Destroying the model destroys transitions
project.destroy!  # cascades to project_transitions
```

---

## 8. Namespaced models

```bash
rails "statesman_scaffold:generate[Admin::Order]"
```

Creates:
```
app/models/admin/order/state_machine.rb     # Admin::Order::StateMachine
app/models/admin/order/transition.rb        # Admin::Order::Transition
db/migrate/TIMESTAMP_create_admin_order_transitions.rb
```

The migration uses:
- Table: `admin_order_transitions`
- Foreign key: `{ to_table: :admin_orders }`
- `belongs_to :order` (demodulized)

Model:

```ruby
class Admin::Order < ApplicationRecord
  with_state_machine
end
```

---

## 9. Handling failed transitions

```ruby
# Bang version raises Statesman::TransitionFailedError
begin
  project.transition_to!(:invalid_state)
rescue Statesman::TransitionFailedError => e
  # handle error
end

# Non-bang version returns false
if project.transition_to(:pending)
  # success
else
  # transition not allowed
end
```

---

## 10. Manual include (without the Rails initializer)

For non-standard setups or when you want explicit control:

```ruby
class Project < ApplicationRecord
  include StatesmanScaffold::Concern
  with_state_machine
end
```

You must also configure Statesman manually:

```ruby
# config/initializers/statesman.rb
require "statesman"
Statesman.configure { storage_adapter(Statesman::Adapters::ActiveRecord) }
```

---

## 11. Migration for the parent model

The generator creates the transitions table. The parent model table is your
responsibility:

```ruby
class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :status, default: "active"
      t.timestamps
    end
  end
end
```

The `status` column is optional — it's a convenience for quick reads. The
source of truth is always the Statesman transition history.

---

## 12. Complete working example

```ruby
# db/migrate/001_create_projects.rb
class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :status, default: "active"
      t.timestamps
    end
  end
end

# app/models/project/state_machine.rb (generated)
class Project::StateMachine
  include Statesman::Machine

  state :active, initial: true
  state :pending
  state :done
  state :cancelled

  transition from: :active, to: %i[pending cancelled]
  transition from: :pending, to: %i[done cancelled]

  after_transition do |model, transition|
    model.update!(status: transition.to_state)
  end
end

# app/models/project/transition.rb (generated)
class Project::Transition < ApplicationRecord
  self.table_name = "project_transitions"

  belongs_to :project, class_name: "Project"

  attribute :most_recent, :boolean, default: false
  attribute :to_state, :string
  attribute :sort_key, :integer
  attribute :metadata, :json, default: {}

  validates :to_state, inclusion: { in: Project::StateMachine.states }
end

# app/models/project.rb
class Project < ApplicationRecord
  STATUSES = Project::StateMachine.states

  with_state_machine

  attribute :status, :string, default: Project::StateMachine.initial_state

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
end

# Usage
project = Project.create!(name: "Alpha")
project.current_state                    # => "active"
project.transition_to!(:pending)
project.status                           # => "pending"
Project.in_state(:pending).count         # => 1
```

---

## 13. Testing models with state machines

```ruby
# Minitest
class ProjectTest < ActiveSupport::TestCase
  test "starts in active state" do
    project = Project.create!(name: "Test")
    assert_equal "active", project.current_state
    assert project.in_state?(:active)
  end

  test "can transition from active to pending" do
    project = Project.create!(name: "Test")
    assert project.can_transition_to?(:pending)
    project.transition_to!(:pending)
    assert_equal "pending", project.current_state
    assert_equal "pending", project.status
  end

  test "cannot transition to invalid state" do
    project = Project.create!(name: "Test")
    refute project.can_transition_to?(:active)
    assert_raises(Statesman::TransitionFailedError) do
      project.transition_to!(:active)
    end
  end

  test "records transitions in the database" do
    project = Project.create!(name: "Test")
    project.transition_to!(:pending)
    assert_equal 1, project.transitions.count
    assert_equal "pending", project.transitions.last.to_state
  end
end
```

---

## 14. Error reference

| Error | Cause | Fix |
|-------|-------|-----|
| `NameError: uninitialized constant Statesman` | Initializer runs before `statesman` gem is loaded | Re-run `rails statesman_scaffold:install` (includes `require "statesman"`) |
| `NameError: uninitialized constant Model::StateMachine` | StateMachine class not generated or not autoloaded | Run `rails "statesman_scaffold:generate[Model]"` |
| `Statesman::TransitionFailedError` | Transition not defined for current state | Check `transition from:` rules in StateMachine |
| `ActiveRecord::StatementInvalid` (missing table) | Migration not run | Run `rails db:migrate` |
| Status column out of sync with `current_state` | No `after_transition` callback | Add `after_transition { \|m, t\| m.update!(status: t.to_state) }` |
| `Statesman::TransitionConflictError` | Concurrent transition race condition | Retry or use database locks |
