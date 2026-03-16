# statesman_scaffold — Usage Patterns

## Pattern 1: Basic State Machine with Status Column Sync

```ruby
# app/models/project/state_machine.rb
class Project::StateMachine
  include Statesman::Machine

  state :pending, initial: true
  state :active
  state :done
  state :cancelled

  transition from: :pending,  to: %i[active cancelled]
  transition from: :active,   to: %i[done cancelled]

  # Keep status column in sync after every transition
  after_transition do |model, transition|
    model.update!(status: transition.to_state)
  end
end

# app/models/project.rb
class Project < ApplicationRecord
  STATUSES = Project::StateMachine.states

  with_state_machine

  attribute :status, :string, default: Project::StateMachine.initial_state
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
end
```

## Pattern 2: Guard Transitions

Guards prevent a transition from firing unless a condition is met.
`transition_to!` raises `Statesman::GuardFailedError` when the guard fails.

```ruby
class Order::StateMachine
  include Statesman::Machine

  state :pending, initial: true
  state :processing
  state :shipped
  state :cancelled

  transition from: :pending,    to: %i[processing cancelled]
  transition from: :processing, to: %i[shipped cancelled]

  guard_transition(to: :processing) do |order|
    order.payment_confirmed?
  end

  guard_transition(to: :shipped) do |order|
    order.all_items_in_stock?
  end
end
```

## Pattern 3: Before / After Callbacks

```ruby
class Order::StateMachine
  include Statesman::Machine

  state :pending, initial: true
  state :purchased
  state :shipped

  transition from: :pending,   to: :purchased
  transition from: :purchased, to: :shipped

  before_transition(to: :purchased) do |order, _transition|
    PaymentService.new(order).charge!
  end

  after_transition(to: :purchased) do |order, _transition|
    OrderMailer.confirmation(order).deliver_later
  end

  after_transition(to: :shipped) do |order, transition|
    order.update!(shipped_at: Time.current)
    ShippingMailer.dispatch(order).deliver_later
  end

  # Runs on every transition
  after_transition do |model, transition|
    model.update!(status: transition.to_state)
  end
end
```

## Pattern 4: Transition Metadata

Pass arbitrary data through the `metadata:` keyword. Stored as JSON.

```ruby
order.transition_to!(:cancelled, metadata: { reason: "customer_request", agent_id: 42 })

# Read it back
last = order.transitions.last
last.metadata["reason"]    # => "customer_request"
last.metadata["agent_id"]  # => 42
```

Access metadata inside callbacks:

```ruby
after_transition(to: :cancelled) do |order, transition|
  reason = transition.metadata["reason"]
  AuditLog.create!(order: order, event: "cancelled", reason: reason)
end
```

## Pattern 5: Class-Level Query Scopes

`with_state_machine` includes `Statesman::Adapters::ActiveRecordQueries`, which
adds `.in_state` and `.not_in_state` class-level scopes.

```ruby
Order.in_state(:pending)
Order.in_state(:pending, :processing)   # any of these states
Order.not_in_state(:cancelled)

# Compose with other AR scopes
Order.where(customer: current_user).in_state(:pending)
Order.in_state(:shipped).where("shipped_at > ?", 7.days.ago)
```

Note: `.in_state` / `.not_in_state` are class-level scopes, not the same as
instance `in_state?` / `not_in_state?` predicates.

## Pattern 6: Instance State Checks

```ruby
project.current_state              # => "pending" (String)
project.in_state?(:pending)        # => true
project.in_state?(:done, :pending) # => true (matches any)
project.in_state?("pending")       # => true (strings work)
project.not_in_state?(:done)       # => true (single state only)
project.can_transition_to?(:active)  # => true / false (checks guards too)
```

## Pattern 7: Transition History

```ruby
project.transitions                   # => ActiveRecord::Associations::CollectionProxy
project.transitions.count             # => 2
project.transitions.last.to_state     # => "active"
project.transitions.last.created_at   # => timestamp
project.transitions.last.metadata     # => {}

# All states the record has been in
project.transitions.pluck(:to_state)  # => ["active", "done"]
```

## Pattern 8: Namespaced Models

```bash
rails "statesman_scaffold:generate[Admin::Order]"
```

Creates:
```
app/models/admin/order/state_machine.rb     # Admin::Order::StateMachine
app/models/admin/order/transition.rb        # Admin::Order::Transition
db/migrate/TIMESTAMP_create_admin_order_transitions.rb
```

Migration uses `{ to_table: :admin_orders }` for the foreign key because the
table name (`admin_order_transitions`) and the demodulized name (`orders`) differ.

Model:

```ruby
class Admin::Order < ApplicationRecord
  with_state_machine
end
```

## Pattern 9: Custom Class Name Suffixes

If your project uses non-standard class name conventions:

```ruby
class Project < ApplicationRecord
  with_state_machine(
    state_machine_suffix: "SM",        # looks for Project::SM
    transition_suffix: "StateChange"   # looks for Project::StateChange
  )
end
```

## Pattern 10: Service Object Using State Transitions

```ruby
class Projects::Complete
  def initialize(project:, metadata: {})
    @project  = project
    @metadata = metadata
  end

  def call
    return false unless @project.can_transition_to?(:done)

    @project.transition_to!(:done, metadata: @metadata)
    true
  rescue Statesman::TransitionFailedError, Statesman::GuardFailedError
    false
  end
end
```

## Pattern 11: Handling Concurrent Transitions

Concurrent writes can cause `Statesman::TransitionConflictError` due to the
`most_recent` uniqueness constraint. Use a retry loop or pessimistic locking:

```ruby
# Simple retry
retries = 0
begin
  order.transition_to!(:processing)
rescue Statesman::TransitionConflictError
  retries += 1
  retry if retries < 3
  raise
end

# Pessimistic lock
Order.transaction do
  order.lock!
  order.transition_to!(:processing)
end
```

## Pattern 12: Guard Failed vs Transition Failed

```ruby
# Statesman::TransitionFailedError — transition not defined in the machine
project.transition_to!(:nonexistent)   # raises TransitionFailedError

# Statesman::GuardFailedError — guard returned false
project.transition_to!(:active)        # raises GuardFailedError if guard fails

# Non-bang version returns false for both cases
project.transition_to(:active)         # => false (no exception)

# can_transition_to? checks both rules and guards
project.can_transition_to?(:active)    # => false if rule missing or guard fails
```

## Pattern 13: Replacing Case/When with State Checks

```ruby
# ❌ Before
def badge_class
  case project.status
  when "pending"   then "badge-warning"
  when "active"    then "badge-success"
  when "cancelled" then "badge-danger"
  end
end

# ✅ After
def badge_class
  return "badge-warning" if project.in_state?(:pending)
  return "badge-success" if project.in_state?(:active)
  "badge-danger"
end
```

## Error Reference

| Error | Cause | Fix |
|-------|-------|-----|
| `NameError: uninitialized constant Statesman` | Initializer runs before `statesman` is loaded | Re-run `rails statesman_scaffold:install` |
| `NameError: uninitialized constant Model::StateMachine` | StateMachine not generated or not autoloaded | Run `rails "statesman_scaffold:generate[Model]"` |
| `Statesman::TransitionFailedError` | Transition not defined for current state | Check `transition from:` rules in StateMachine |
| `Statesman::GuardFailedError` | Guard block returned false | Check guard conditions or use non-bang `transition_to` |
| `ActiveRecord::StatementInvalid` (missing table) | Migration not run | Run `rails db:migrate` |
| `Statesman::TransitionConflictError` | Concurrent transition race condition | Use retry or pessimistic locking |
| Status out of sync with `current_state` | No `after_transition` callback | Add `after_transition { \|m, t\| m.update!(status: t.to_state) }` |
