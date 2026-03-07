# AGENTS.md — statesman_scaffold

> Concise reference for AI coding agents working **on** the `statesman_scaffold`
> gem or **with** it inside a host Rails application.
>
> For end-user documentation see `README.md`.
> For LLM-optimised usage patterns see `llms/usage.md`.
> For architecture details see `llms/overview.md`.

---

## What this gem does

`statesman_scaffold` scaffolds [Statesman](https://github.com/gocardless/statesman)
state machines for ActiveRecord models and provides a `with_state_machine`
concern that wires up delegation, query scopes, and transition associations.

```ruby
# 1. Generate files
# rails "statesman_scaffold:generate[Project]"

# 2. Add to model
class Project < ApplicationRecord
  with_state_machine
end

# 3. Use
project = Project.create!(name: "Demo")
project.current_state           # => "pending"
project.transition_to!(:active)
project.in_state?(:active)      # => true
```

It is a **Rails-only** gem (depends on `activesupport >= 7`, `activerecord >= 7`,
`railties >= 7`, `statesman >= 10`). Works only with
`Statesman::Adapters::ActiveRecord`.

---

## Quick integration checklist (host app)

```bash
bundle add statesman_scaffold
rails statesman_scaffold:install       # creates config/initializers/statesman_scaffold.rb
rails "statesman_scaffold:generate[ModelName]"  # generates files
```

After `install` every model inherits the `with_state_machine` macro. No
`include` needed.

---

## `with_state_machine` macro signature

```ruby
with_state_machine(
  transition_suffix: "Transition",
  state_machine_suffix: "StateMachine"
)
```

| Parameter | Type | Default | Notes |
|-----------|------|---------|-------|
| `transition_suffix` | `String` | `"Transition"` | Suffix for the transition class |
| `state_machine_suffix` | `String` | `"StateMachine"` | Suffix for the state machine class |

The macro expects `Model::StateMachine` and `Model::Transition` to exist.
Use the `generate` rake task to create them.

---

## Instance methods added by the concern

| Method | Delegates to | Description |
|--------|-------------|-------------|
| `current_state` | `state_machine` | Returns the current state as a string |
| `transition_to!(state)` | `state_machine` | Transitions to state; raises on failure |
| `transition_to(state)` | `state_machine` | Transitions to state; returns `true`/`false` |
| `can_transition_to?(state)` | `state_machine` | Checks if transition is valid |
| `in_state?(*states)` | — | Returns `true` if current state matches any given state |
| `not_in_state?(state)` | — | Returns `true` if current state does not match |

Class-level scopes from `Statesman::Adapters::ActiveRecordQueries`:
- `Model.in_state(:active, :pending)`
- `Model.not_in_state(:cancelled)`

---

## Rules agents must follow

### Always
- Run `rails statesman_scaffold:install` before first use in a host app.
- Call `with_state_machine` **after** any custom `has_many` declarations.
- Define states, transitions, and callbacks in the generated `StateMachine` class.
- Add an `after_transition` callback to sync the status column if you have one.
- Run `rails db:migrate` after generating files.
- The `statesman` gem must be in the host app's Gemfile.

### Never
- Manually create StateMachine/Transition classes without the generator (or follow the exact template patterns).
- Call `with_state_machine` more than once on the same model.
- Define a `has_many :transitions` on the model — `with_state_machine` does it.
- Stub `Rails.root` in tests — use `Installer.install!(tmpdir)` or `Generator.call(...)` with real paths.

---

## Gem internals (working on the gem itself)

### Module map

| File | Responsibility |
|------|----------------|
| `lib/statesman_scaffold/concern.rb` | `with_state_machine` class macro + `in_state?`/`not_in_state?` |
| `lib/statesman_scaffold/generator.rb` | ERB template rendering for StateMachine, Transition, migration |
| `lib/statesman_scaffold/installer.rb` | Creates/removes `config/initializers/statesman_scaffold.rb` |
| `lib/statesman_scaffold/railtie.rb` | Registers all `statesman_scaffold:*` rake tasks |
| `lib/tasks/statesman_scaffold.rake` | Rake task implementations (install/uninstall/generate) |
| `lib/templates/statesman/*.erb` | ERB templates for generated files |

### Generated files (per model)

| Template | Output | Description |
|----------|--------|-------------|
| `state_machine.rb.erb` | `app/models/<model>/state_machine.rb` | Statesman::Machine class with example states |
| `transition.rb.erb` | `app/models/<model>/transition.rb` | Transition model with validations |
| `migration.rb.erb` | `db/migrate/TIMESTAMP_create_<model>_transitions.rb` | Migration with indexes |

### Test suite

```bash
bundle exec rake test     # Minitest with SQLite in-memory
bundle exec rake          # default task
```

Tests live in `test/statesman_scaffold/`. Each test class uses `setup`/`teardown`
to create and drop SQLite tables so tests are fully isolated.

### Adding a new test

1. Extend `Minitest::Test` inside the `StatesmanScaffold` module namespace.
2. Name the file `test/statesman_scaffold/<feature>_test.rb`.
3. Create tables in `setup`, drop them in `teardown`.
4. Generator/Installer tests use `Dir.mktmpdir` for filesystem isolation.

---

## Common pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| `NameError: uninitialized constant Statesman` | Initializer runs before `statesman` gem is loaded | Ensure `gem "statesman"` is in Gemfile; re-run `rails statesman_scaffold:install` (initializer now includes `require "statesman"`) |
| `NameError: uninitialized constant Model::StateMachine` | StateMachine class not generated or not loaded | Run `rails "statesman_scaffold:generate[Model]"` and ensure file is in autoload path |
| `Statesman::TransitionFailedError` | Transition not allowed from current state | Check `StateMachine` class transition rules |
| `ActiveRecord::StatementInvalid` (missing table) | Migration not run | Run `rails db:migrate` |
| Transitions not persisted | Statesman not configured for AR adapter | Run `rails statesman_scaffold:install` |
| Status column not updated after transition | No `after_transition` callback | Add `after_transition { |m, t| m.update!(status: t.to_state) }` to StateMachine |

---

## Dependencies

| Gem | Version | Why |
|-----|---------|-----|
| `statesman` | `>= 10.0, < 13` | State machine engine |
| `activerecord` | `>= 7.0, < 9` | AR integration (has_many, migrations) |
| `activesupport` | `>= 7.0, < 9` | `Concern`, `camelize`, `underscore`, `on_load` |
| `railties` | `>= 7.0, < 9` | `Rails::Railtie` for exposing rake tasks |
| `sqlite3` | dev only | In-memory DB for tests |
| `minitest` | dev only | Test framework |

---

## Test conventions

- Use `Minitest::Test` (not `ActiveSupport::TestCase`)
- AR schema is created in `setup` with `force: true` and dropped in `teardown`
- `InstallerTest` and `GeneratorTest` use `Dir.mktmpdir` — always clean up in `teardown`
- `assert` / `refute` preferred over `assert_equal true/false`
- Group related tests with comment banners: `# --- install! ---`
- Test method names describe the exact behaviour: `test_install_creates_the_initializer_file`
