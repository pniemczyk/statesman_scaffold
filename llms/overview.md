# StatesmanScaffold -- Architecture Overview

> Intended audience: LLMs and AI agents that need a precise mental model of
> the gem internals before generating code.

---

## Purpose

`statesman_scaffold` provides two things for Rails applications using the
[Statesman](https://github.com/gocardless/statesman) gem:

1. **Code generation** — a rake task that creates StateMachine, Transition
   classes, and a migration for any ActiveRecord model.
2. **A concern** — `with_state_machine` class macro that wires up Statesman
   delegation, `has_many :transitions`, query scopes, and convenience predicates.

It works exclusively with `Statesman::Adapters::ActiveRecord`.

---

## Module structure

```
StatesmanScaffold                      (top-level namespace, lib/statesman_scaffold.rb)
├── Concern                            (lib/statesman_scaffold/concern.rb)
│   ├── included block
│   │   ├── in_state?(*states)        → checks current state against multiple states
│   │   ├── not_in_state?(state)      → negation of in_state?
│   │   └── delegate :current_state, :transition_to!, :transition_to, :can_transition_to?
│   └── class_methods
│       └── with_state_machine(...)   → wires up has_many, ActiveRecordQueries, state_machine method
├── Generator                          (lib/statesman_scaffold/generator.rb)
│   ├── TEMPLATE_DIR                  → path to lib/templates/statesman/
│   ├── Result                        → Struct(state_machine_path, transition_path, migration_path)
│   └── .call(model:, output_path:, migration_path:, migration_version:, timestamp:)
├── Installer                          (lib/statesman_scaffold/installer.rb)
│   ├── INITIALIZER_PATH             → Pathname("config/initializers/statesman_scaffold.rb")
│   ├── INITIALIZER_CONTENT          → the exact string written to disk
│   ├── .install!(rails_root)        → :created or :skipped
│   └── .uninstall!(rails_root)      → :removed or :skipped
├── Railtie < Rails::Railtie          (lib/statesman_scaffold/railtie.rb)
│   └── rake_tasks { load ... }      → exposes all statesman_scaffold:* rake tasks
└── Error < StandardError
```

---

## How `with_state_machine` works

```ruby
class Project < ApplicationRecord
  with_state_machine
end
```

When `with_state_machine` is called, it:

1. **Resolves class names dynamically** from the model's `name`:
   - `"Project"` → `"Project::StateMachine"` and `"Project::Transition"`
   - `"Admin::Order"` → `"Admin::Order::StateMachine"` and `"Admin::Order::Transition"`

2. **Adds `has_many :transitions`** with `autosave: false`, `dependent: :destroy`,
   and the resolved `class_name`.

3. **Includes `Statesman::Adapters::ActiveRecordQueries`** parameterised with
   `transition_class` and `initial_state`, giving the model `.in_state` and
   `.not_in_state` class-level scopes.

4. **Defines a `state_machine` instance method** that lazily initialises and
   caches a Statesman machine instance via `instance_variable_set(:@state_machine, ...)`.

The `included` block adds `in_state?`, `not_in_state?`, and delegates
`current_state`, `transition_to!`, `transition_to`, `can_transition_to?` to
`state_machine`.

### Class name resolution

```ruby
model_name      = name                          # e.g. "Admin::Order"
model_namespace = model_name.deconstantize      # e.g. "Admin"
model_base      = model_name.demodulize         # e.g. "Order"

transition_class_name    = [model_namespace.presence, model_base, "Transition"].compact.join("::")
state_machine_class_name = [model_namespace.presence, model_base, "StateMachine"].compact.join("::")
```

Both class names are constantised at call time (`constantize`), so the nested
classes must already be defined (autoloaded) when the model is first used.

### `in_state?` / `not_in_state?`

```ruby
def in_state?(*states)
  states.any? { |s| current_state.to_sym == s.to_sym }
end

def not_in_state?(state)
  !in_state?(state)
end
```

Both accept symbols or strings. `in_state?` accepts multiple states (returns
`true` if current state matches any). `not_in_state?` accepts a single state.

---

## Generator architecture

`StatesmanScaffold::Generator` is a pure Ruby class with no Rails dependency.
It reads ERB templates from `lib/templates/statesman/` and writes rendered
output to caller-specified paths.

### Templates

**`state_machine.rb.erb`** — creates `Model::StateMachine` with
`include Statesman::Machine`, an initial `:pending` state, and commented
examples of states, transitions, guards, and callbacks.

**`transition.rb.erb`** — creates `Model::Transition < ApplicationRecord` with:
- `self.table_name` set to `"<underscored_model>_transitions"`
- `belongs_to` the parent model
- Attributes: `most_recent`, `to_state`, `sort_key`, `metadata`
- Validates `to_state` inclusion against `Model::StateMachine.states`

**`migration.rb.erb`** — creates a migration with:
- `create_table` for `<underscored_model>_transitions`
- `t.references` with foreign key (handles namespaced models with `to_table:`)
- `to_state`, `metadata`, `most_recent`, `sort_key`, `timestamps`
- Two unique indexes: `parent_sort` and `parent_most_recent` (with `WHERE most_recent`)

### Template variables

| Variable | Example | Source |
|----------|---------|--------|
| `model` | `"Admin::Order"` | Input parameter |
| `class_name` | `"Admin::Order"` | Same as `model` (camelized) |
| `underscored_model` | `"admin_order"` | `model.underscore.tr("/", "_")` |
| `demodulized_model` | `"order"` | `model.demodulize.underscore` |
| `version` | `"8.0"` | Migration version |

### Namespaced model handling

For `Admin::Order`:
- Table name: `admin_order_transitions`
- `belongs_to :order` (demodulized)
- Foreign key: `{ to_table: :admin_orders }` (because `underscored_model != demodulized_model`)
- Migration class: `CreateAdminOrderTransitions`

---

## Installer architecture

```
Rails app                    statesman_scaffold gem
─────────────────            ──────────────────────────────────────────────────
Gemfile ──requires──▶  lib/statesman_scaffold.rb
                            └── lib/statesman_scaffold/railtie.rb  (only if Rails::Railtie defined)
                                    └── rake_tasks { load 'lib/tasks/statesman_scaffold.rake' }

$ rails statesman_scaffold:install
                       ──▶  task :install
                                └── StatesmanScaffold::Installer.install!(Rails.root)
                                        └── writes config/initializers/statesman_scaffold.rb
```

**Why Installer is a separate class:** The rake task calls `Rails.root`, which is
unavailable in tests without a full Rails boot. By pushing all logic into
`Installer.install!(root)`, tests can pass any `Pathname` as the root — no
stubbing, no Rake DSL needed.

**The generated initializer** contains:

```ruby
require "statesman"

Statesman.configure { storage_adapter(Statesman::Adapters::ActiveRecord) }

ActiveSupport.on_load(:active_record) do
  include StatesmanScaffold::Concern
end
```

The `require "statesman"` ensures the Statesman constant is available when the
initializer runs. Without it, if Statesman is autoloaded later, the initializer
would fail with `NameError: uninitialized constant Statesman`.

---

## Rake tasks

| Task | Depends on | Description |
|------|-----------|-------------|
| `statesman_scaffold:install` | — | Delegates to `Installer.install!(Rails.root)` |
| `statesman_scaffold:uninstall` | — | Delegates to `Installer.uninstall!(Rails.root)` |
| `statesman_scaffold:generate[Model]` | `:environment` | Delegates to `Generator.call(...)` |

The `generate` task:
1. Camelizes the model argument
2. Computes `output_path` as `Rails.root.join("app/models", model.underscore)`
3. Sets `migration_path` to `Rails.root.join("db/migrate")`
4. Reads `migration_version` from `ActiveRecord::Migration.current_version`
5. Calls `Generator.call` and prints relative paths of created files
6. Prints a reminder to add `with_state_machine` to the model

---

## Testing architecture

| Component | Tool | Isolation |
|-----------|------|-----------|
| Concern (with_state_machine) | Minitest | SQLite in-memory tables |
| Generator | Minitest | `Dir.mktmpdir` filesystem |
| Installer | Minitest | `Dir.mktmpdir` filesystem |

`test_helper.rb` boots ActiveRecord against SQLite, configures Statesman with
the AR adapter, and calls `ActiveSupport.on_load(:active_record) { include
StatesmanScaffold::Concern }` to replicate what the Rails initializer does.

### Concern test setup

Test models are defined in a `SmTestModels` namespace with inline
`StateMachine` and `Transition` classes. Tables are created in `setup` and
dropped in `teardown`:

- `sm_projects` — main model table
- `sm_project_transitions` — transitions table

This avoids polluting the global namespace and provides full test isolation.

### Generator test setup

Uses `Dir.mktmpdir` to create a temporary directory. Calls `Generator.call`
with temporary paths. Asserts file existence, content patterns, and Ruby syntax
validity (`ruby -c`).

---

## File inclusion in gem package

```ruby
spec.files = Dir[
  "lib/**/*.rb",
  "lib/templates/**/*.erb",
  "lib/tasks/*.rake",
  "llms/**/*.md",
  "AGENTS.md",
  "CLAUDE.md",
  "README.md",
  "LICENSE.txt",
  "CHANGELOG.md"
]
```

LLM context files (`llms/`, `AGENTS.md`, `CLAUDE.md`) ship inside the released
gem so that tools that install the gem can serve them as context to AI assistants.
