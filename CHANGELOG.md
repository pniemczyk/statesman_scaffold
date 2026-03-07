# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-03-07

### Added

- `StatesmanScaffold::Concern` with the `with_state_machine` class macro
- `in_state?` and `not_in_state?` instance methods for state checking
- Delegation of `current_state`, `transition_to!`, `transition_to`, `can_transition_to?`
- `Statesman::Adapters::ActiveRecordQueries` integration for query scopes
- `StatesmanScaffold::Generator` for creating StateMachine, Transition, and migration files from ERB templates
- `StatesmanScaffold::Installer` for creating/removing the Rails initializer
- `StatesmanScaffold::Railtie` with `statesman_scaffold:install`, `statesman_scaffold:uninstall`, and `statesman_scaffold:generate` rake tasks
- Support for namespaced models (e.g. `Admin::Order`)
