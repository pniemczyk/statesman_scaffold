---
name: statesman-scaffold
description: This skill should be used when the user asks to "add statesman_scaffold", "install statesman_scaffold", "add a state machine to a Rails model", "scaffold a Statesman state machine", "add state machine transitions", "generate state machine files", "use statesman in Rails", "add with_state_machine", "add transition history to a model", "add current_state / transition_to to a model", or when working with the statesman_scaffold gem in a Rails project. Also activate when the user wants to add `.in_state?`, `.can_transition_to?`, `.transition_to!`, `.in_state` scopes, or asks about Statesman guards, callbacks, or the transitions table.
version: 1.0.0
---

# statesman_scaffold Skill

`statesman_scaffold` scaffolds [Statesman](https://github.com/gocardless/statesman) state machines for ActiveRecord models. It generates `StateMachine`, `Transition` classes, and a migration via rake tasks, then wires everything up with a single `with_state_machine` macro call.

## What It Does

```ruby
# Before — manual wiring every time
class Project < ApplicationRecord
  has_many :project_transitions, dependent: :destroy
  include Statesman::Adapters::ActiveRecordQueries[...]
  # ...delegate :current_state, :transition_to!, etc.
end

# After — one macro does it all
class Project < ApplicationRecord
  with_state_machine
end

project.current_state              # => "pending"
project.transition_to!(:active)
project.in_state?(:active)         # => true
Project.in_state(:active).count    # => 1
```

## Installation

See **`references/installation.md`** for full steps. Quick summary:

```ruby
# Gemfile
gem "statesman"
gem "statesman_scaffold"
```

```bash
bundle install
rails statesman_scaffold:install   # writes config/initializers/statesman_scaffold.rb
```

The initializer:
1. `require "statesman"` — ensures the constant is available
2. Configures Statesman to use the `ActiveRecord` adapter
3. Auto-includes `StatesmanScaffold::Concern` into every AR model via `on_load`

## Generate State Machine Files

```bash
rails "statesman_scaffold:generate[Project]"
rails db:migrate
```

Creates three files under `app/models/project/`:

| File | Class |
|------|-------|
| `state_machine.rb` | `Project::StateMachine` |
| `transition.rb` | `Project::Transition` |
| `db/migrate/TIMESTAMP_create_project_transitions.rb` | migration |

## Configure the StateMachine

Edit the generated `app/models/project/state_machine.rb`:

```ruby
class Project::StateMachine
  include Statesman::Machine

  state :pending, initial: true
  state :active
  state :done
  state :cancelled

  transition from: :pending,  to: %i[active cancelled]
  transition from: :active,   to: %i[done cancelled]

  # Sync status column after every transition
  after_transition do |model, transition|
    model.update!(status: transition.to_state)
  end
end
```

## Configure the Model

```ruby
class Project < ApplicationRecord
  STATUSES = Project::StateMachine.states

  with_state_machine

  attribute :status, :string, default: Project::StateMachine.initial_state
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
end
```

## Instance Methods (provided by `with_state_machine`)

| Method | Description |
|--------|-------------|
| `current_state` | Current state as a String |
| `transition_to!(:state)` | Transition; raises `Statesman::TransitionFailedError` on failure |
| `transition_to(:state)` | Transition; returns `true` / `false` |
| `can_transition_to?(:state)` | Returns `true` / `false` |
| `in_state?(:a, :b)` | `true` if current state matches any given state (symbol or string) |
| `not_in_state?(:state)` | Negation of `in_state?` (single state only) |

## Class-Level Scopes

```ruby
Project.in_state(:active)
Project.in_state(:active, :pending)   # any of these states
Project.not_in_state(:cancelled)
Project.where(team: "Engineering").in_state(:active)
```

## ⚠️ Critical Notes

**`StateMachine` and `Transition` classes must exist before `with_state_machine` is called.**
The macro `constantize`s both class names at call time. If either is missing, you get a `NameError`.

**Always run the generator before adding `with_state_machine` to the model.**

**The status column is optional** — it's a convenience for fast reads. The source of truth is always the Statesman transition history (`project.transitions`).

**Namespaced models work** — `rails "statesman_scaffold:generate[Admin::Order]"` places files under `app/models/admin/order/` and correctly sets the foreign key.

See **`references/patterns.md`** for guards, callbacks, namespaced models, transition metadata, and concurrent-transition handling.

## Common Mistakes

```ruby
# ❌ with_state_machine called before StateMachine class is loaded
class Project < ApplicationRecord
  with_state_machine   # raises NameError: uninitialized constant Project::StateMachine
end
# → generate the files first, then add the macro

# ❌ forgetting rails db:migrate after generate
# → ActiveRecord::StatementInvalid: no such table: project_transitions

# ❌ status column out of sync with current_state
# → add `after_transition { |m, t| m.update!(status: t.to_state) }` to StateMachine

# ❌ calling in_state? with a string you also defined as a column name
project.in_state?("active")   # ✅ fine — accepts strings and symbols
```

## Additional Resources

### Reference Files

- **`references/installation.md`** — Full setup steps, initializer content, rake tasks, uninstalling
- **`references/patterns.md`** — Guards, callbacks, namespaced models, metadata, error handling, scopes

### Examples

- **`examples/activerecord.rb`** — Complete model + state machine setup
- **`examples/namespaced.rb`** — Namespaced model (`Admin::Order`)
- **`examples/testing.rb`** — Minitest patterns for state machine models
