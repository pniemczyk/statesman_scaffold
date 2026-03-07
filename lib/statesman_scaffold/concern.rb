# frozen_string_literal: true

require "active_support/concern"

module StatesmanScaffold
  # ActiveSupport::Concern that provides the +with_state_machine+ class macro
  # for wiring up Statesman state machines to ActiveRecord models.
  #
  # @example
  #   class Project < ApplicationRecord
  #     include StatesmanScaffold::Concern
  #     with_state_machine
  #   end
  #
  #   project = Project.create!(name: "Demo")
  #   project.current_state          # => "pending"
  #   project.can_transition_to?(:active) # => true/false
  #   project.transition_to!(:active)
  #   project.in_state?(:active)     # => true
  #   project.not_in_state?(:pending) # => true
  module Concern
    extend ActiveSupport::Concern

    included do
      # Check if the model is currently in any of the given states.
      #
      # @param states [Array<String, Symbol>] one or more state names
      # @return [Boolean]
      def in_state?(*states)
        states.any? { |s| current_state.to_sym == s.to_sym }
      end

      # Check if the model is NOT in the given state.
      #
      # @param state [String, Symbol] a state name
      # @return [Boolean]
      def not_in_state?(state)
        !in_state?(state)
      end

      delegate :can_transition_to?, :transition_to!, :transition_to, :current_state, to: :state_machine
    end

    class_methods do
      # Wires up the Statesman state machine for this model.
      #
      # Expects nested +StateMachine+ and +Transition+ classes to exist under
      # the model's namespace (e.g. +Project::StateMachine+, +Project::Transition+).
      #
      # Use the +statesman_scaffold:generate+ rake task to create these classes
      # and the corresponding migration.
      #
      # @param transition_suffix [String] suffix for the transition class (default: "Transition")
      # @param state_machine_suffix [String] suffix for the state machine class (default: "StateMachine")
      def with_state_machine(transition_suffix: "Transition", state_machine_suffix: "StateMachine")
        model_name      = name
        model_namespace = model_name.deconstantize
        model_base      = model_name.demodulize

        transition_class_name     = [model_namespace.presence, model_base, transition_suffix].compact.join("::")
        state_machine_class_name  = [model_namespace.presence, model_base, state_machine_suffix].compact.join("::")

        has_many :transitions,
                 autosave: false,
                 class_name: transition_class_name,
                 dependent: :destroy

        include ::Statesman::Adapters::ActiveRecordQueries[
          transition_class: transition_class_name.constantize,
          initial_state: state_machine_class_name.constantize.initial_state
        ]

        define_method(:state_machine) do
          instance_variable_get(:@state_machine) ||
            instance_variable_set(
              :@state_machine,
              state_machine_class_name.constantize.new(
                self,
                transition_class: transition_class_name.constantize,
                association_name: :transitions
              )
            )
        end
      end
    end
  end
end
