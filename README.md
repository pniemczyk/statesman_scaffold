# StatesmanScaffold

Scaffold [Statesman](https://github.com/gocardless/statesman) state machines for ActiveRecord models. Generates StateMachine, Transition classes, and migrations with a single rake task, plus a `with_state_machine` concern that wires up delegation, query scopes, and transition associations.

## Features

* One rake task generates StateMachine class, Transition model, and migration
* `with_state_machine` class macro wires up Statesman with a single line
* Delegates `current_state`, `transition_to!`, `transition_to`, `can_transition_to?` to the state machine
* Adds `in_state?` and `not_in_state?` convenience predicates
* Includes `Statesman::Adapters::ActiveRecordQueries` for query scopes
* Supports namespaced models (e.g. `Admin::Order`)
* Rails installer that configures Statesman adapter and auto-includes the concern

## Installation

Add to your application's `Gemfile`:

```ruby
gem "statesman_scaffold"
```

Then run:

```bash
bundle install
rails statesman_scaffold:install
```

The installer creates `config/initializers/statesman_scaffold.rb` which configures Statesman to use the ActiveRecord adapter and auto-includes `StatesmanScaffold::Concern` into every ActiveRecord model.

## Usage

### Generate state machine files

```bash
rails "statesman_scaffold:generate[Project]"
```

This creates three files:

* `app/models/project/state_machine.rb` – the Statesman state machine class
* `app/models/project/transition.rb` – the transition model
* `db/migrate/TIMESTAMP_create_project_transitions.rb` – the migration

### Configure your model

```ruby
class Project < ApplicationRecord
  STATUSES = Project::StateMachine.states

  with_state_machine

  attribute :status, :string, default: Project::StateMachine.initial_state
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
end
```

### Define states and transitions

Edit the generated `app/models/project/state_machine.rb`:

```ruby
class Project::StateMachine
  include Statesman::Machine

  state :active, initial: true
  state :pending
  state :skipped
  state :cancelled
  state :done

  transition from: :active, to: [:pending, :skipped, :cancelled, :done]
  transition from: :pending, to: [:skipped, :cancelled, :done]
  transition from: :skipped, to: [:pending]

  after_transition do |model, transition|
    model.update!(status: transition.to_state)
  end
end
```

### Use the state machine

```ruby
project = Project.create!(name: "Demo")

project.current_state              # => "active"
project.in_state?(:active)         # => true
project.not_in_state?(:done)       # => true

project.can_transition_to?(:pending) # => true
project.transition_to!(:pending)
project.current_state              # => "pending"
project.status                     # => "pending"

# Non-bang version returns true/false instead of raising
project.transition_to(:done)       # => true

# Query scopes (via Statesman::Adapters::ActiveRecordQueries)
Project.in_state(:active)
Project.not_in_state(:cancelled)
```

### Namespaced models

```bash
rails "statesman_scaffold:generate[Admin::Order]"
```

This generates `Admin::Order::StateMachine`, `Admin::Order::Transition`, and the corresponding migration with proper table names and foreign keys.

## Rake tasks

```bash
rails statesman_scaffold:install    # create config/initializers/statesman_scaffold.rb
rails statesman_scaffold:uninstall  # remove config/initializers/statesman_scaffold.rb
rails "statesman_scaffold:generate[ModelName]"  # generate state machine files
```

## Manual include (without the Rails initializer)

```ruby
class Project < ApplicationRecord
  include StatesmanScaffold::Concern
  with_state_machine
end
```

## Development

```bash
bin/setup         # install dependencies
bundle exec rake  # run tests
bin/console       # interactive prompt
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pniemczyk/statesman_scaffold.

## License

MIT -- see [LICENSE.txt](LICENSE.txt).
