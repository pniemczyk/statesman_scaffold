# StatesmanScaffold -- Claude Project Context

> Project-level instructions and context for Claude Code when working inside
> the `statesman_scaffold` gem repository.

## Project overview

`statesman_scaffold` is a Ruby gem that scaffolds [Statesman](https://github.com/gocardless/statesman)
state machines for ActiveRecord models. It generates StateMachine, Transition classes,
and migrations via rake tasks, and provides a `with_state_machine` concern for wiring
everything up with a single macro call.

## Repository layout

```
lib/
  statesman_scaffold.rb              # Entry point -- require this in host apps
  statesman_scaffold/
    concern.rb                       # Core: with_state_machine macro via ActiveSupport::Concern
    generator.rb                     # ERB template renderer for state machine files
    installer.rb                     # Manages config/initializers/statesman_scaffold.rb
    railtie.rb                       # Rails integration, exposes rake tasks
    version.rb                       # Version constant
  templates/
    statesman/
      state_machine.rb.erb           # Template for StateMachine class
      transition.rb.erb              # Template for Transition model
      migration.rb.erb               # Template for migration file
  tasks/
    statesman_scaffold.rake          # install / uninstall / generate rake tasks
test/
  test_helper.rb                     # SQLite in-memory, Statesman AR adapter config
  test_statesman_scaffold.rb         # Version number test
  statesman_scaffold/
    concern_test.rb                  # Tests for with_state_machine macro
    generator_test.rb                # Tests for ERB template generation
    installer_test.rb                # Tests for Installer class
llms/
  overview.md                        # Architecture deep-dive for LLMs
  usage.md                           # Common patterns and recipes
AGENTS.md                            # Concise guide for AI coding agents
CLAUDE.md                            # This file
```

## Development workflow

```bash
bundle install
bundle exec rake test      # run Minitest suite (SQLite in-memory)
bundle exec rake           # tests (default)
bin/console                # IRB with gem loaded
```

## Rake tasks (in host Rails apps)

| Task | Description |
|------|-------------|
| `rails statesman_scaffold:install` | Create `config/initializers/statesman_scaffold.rb` |
| `rails statesman_scaffold:uninstall` | Remove `config/initializers/statesman_scaffold.rb` |
| `rails "statesman_scaffold:generate[ModelName]"` | Generate StateMachine, Transition, and migration |

## Code style

- **Double quotes** throughout (enforced by RuboCop).
- Frozen string literals on every file.
- Nested module/class syntax (`module StatesmanScaffold; class Concern`) preferred.
- Test files use `module StatesmanScaffold; class XxxTest < Minitest::Test` nesting.
- Metrics limits: `MethodLength: Max: 15`; test files are excluded from metrics.

## Key design decisions

1. **`with_state_machine` resolves class names dynamically** at call time using
   the model's `name`. It expects `Model::StateMachine` and `Model::Transition`
   to exist (generated via the rake task). Accepts optional `transition_suffix:`
   and `state_machine_suffix:` keyword arguments.

2. **Concern delegates** `current_state`, `transition_to!`, `transition_to`, and
   `can_transition_to?` to a lazily-initialized state machine instance.

3. **`in_state?` accepts multiple states** and compares via `.to_sym` for
   symbol/string interoperability. `not_in_state?` accepts a single state.

4. **Statesman::Adapters::ActiveRecordQueries** is auto-included by
   `with_state_machine`, giving the model class-level `.in_state` and
   `.not_in_state` query scopes.

5. **Generator is decoupled from Rails**: `StatesmanScaffold::Generator` takes
   `Pathname` arguments and never references `Rails.root`, making it unit-testable
   with a `Dir.mktmpdir`. Returns a `Result` struct with all output paths.

6. **Installer is decoupled from Rails**: `StatesmanScaffold::Installer` takes a
   `Pathname` root and never references `Rails.root`, making it unit-testable
   with a `Dir.mktmpdir`.

7. **The generated initializer** does three things:
   - `require "statesman"` (ensures the gem is loaded before configuring)
   - `Statesman.configure { storage_adapter(Statesman::Adapters::ActiveRecord) }`
   - `ActiveSupport.on_load(:active_record) { include StatesmanScaffold::Concern }`

8. **Templates use ERB** with `trim_mode: "-"` and `result_with_hash` for clean
   rendering without binding objects.

## When adding features

- State machine wiring logic belongs in `concern.rb`.
- New public class-level DSL methods belong inside `class_methods do`.
- Template changes go in `lib/templates/statesman/`.
- Update `sig/statesman_scaffold.rbs` when adding or changing public method signatures.
- Write Minitest tests in `test/statesman_scaffold/` before implementing (TDD).
- Run `bundle exec rake` before committing -- must be fully green.

## Dependency notes

- `statesman` provides `Statesman::Machine`, `Statesman::Adapters::ActiveRecord`,
  and `Statesman::Adapters::ActiveRecordQueries`.
- `activerecord` provides `has_many`, `ActiveRecord::Base`, and migrations.
- `activesupport` provides `ActiveSupport::Concern`, `String#camelize`,
  `String#underscore`, `String#demodulize`, `String#deconstantize`.
- `railties` provides `Rails::Railtie` for rake task integration.

## Out of scope (do not add unless explicitly requested)

- Custom transition metadata helpers.
- State machine visualization or diagram generation.
- Support for non-ActiveRecord ORMs.
- Automatic state column management (users define their own status columns).
