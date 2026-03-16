# frozen_string_literal: true

# Namespaced model example: Admin::Order
# Run: rails "statesman_scaffold:generate[Admin::Order]"
#
# Key differences vs a top-level model:
#   - Files land in app/models/admin/order/
#   - Table name: admin_order_transitions
#   - Foreign key uses { to_table: :admin_orders }
#   - belongs_to uses the demodulized name (:order)

# ─── db/migrate/001_create_admin_orders.rb ───────────────────────────────────
class CreateAdminOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_orders do |t|
      t.string :reference, null: false
      t.string :status,    default: "draft"
      t.timestamps
    end
  end
end

# ─── app/models/admin/order/state_machine.rb (generated, then edited) ────────
class Admin::Order::StateMachine
  include Statesman::Machine

  state :draft,      initial: true
  state :submitted
  state :approved
  state :rejected
  state :fulfilled

  transition from: :draft,     to: %i[submitted]
  transition from: :submitted, to: %i[approved rejected]
  transition from: :approved,  to: %i[fulfilled]

  after_transition do |model, transition|
    model.update!(status: transition.to_state)
  end

  after_transition(to: :approved) do |order, transition|
    approver_id = transition.metadata["approver_id"]
    AdminMailer.order_approved(order, approver_id: approver_id).deliver_later
  end

  after_transition(to: :rejected) do |order, transition|
    reason = transition.metadata["reason"]
    AdminMailer.order_rejected(order, reason: reason).deliver_later
  end
end

# ─── app/models/admin/order/transition.rb (generated) ────────────────────────
class Admin::Order::Transition < ApplicationRecord
  self.table_name = "admin_order_transitions"

  # belongs_to uses demodulized name (:order), not (:admin_order)
  belongs_to :order, class_name: "Admin::Order"

  attribute :most_recent, :boolean, default: false
  attribute :to_state, :string
  attribute :sort_key, :integer
  attribute :metadata, :json, default: {}

  validates :to_state, inclusion: { in: Admin::Order::StateMachine.states }
end

# ─── app/models/admin/order.rb ───────────────────────────────────────────────
class Admin::Order < ApplicationRecord
  STATUSES = Admin::Order::StateMachine.states

  with_state_machine

  attribute :status, :string, default: Admin::Order::StateMachine.initial_state

  validates :reference, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
end

# ─── Usage ────────────────────────────────────────────────────────────────────
order = Admin::Order.create!(reference: "ORD-001")

order.current_state                # => "draft"
order.transition_to!(:submitted)
order.transition_to!(:approved, metadata: { approver_id: 7 })
order.current_state                # => "approved"

# Scopes — same API as top-level models
Admin::Order.in_state(:submitted)
Admin::Order.not_in_state(:rejected)
