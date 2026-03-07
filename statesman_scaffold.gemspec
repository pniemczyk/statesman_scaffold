# frozen_string_literal: true

require_relative "lib/statesman_scaffold/version"

Gem::Specification.new do |spec|
  spec.name    = "statesman_scaffold"
  spec.version = StatesmanScaffold::VERSION
  spec.authors = ["Pawel Niemczyk"]
  spec.email   = ["pniemczyk.info@gmail.com"]

  spec.summary     = "Scaffold Statesman state machines for ActiveRecord models"
  spec.description = <<~DESC
    StatesmanScaffold generates StateMachine, Transition classes, and migrations for
    ActiveRecord models using the Statesman gem. Includes a WithStateMachine concern
    that wires up state machine delegation, query scopes, and transition associations
    with a single `with_state_machine` class macro.
  DESC
  spec.homepage = "https://github.com/pniemczyk/statesman_scaffold"
  spec.license  = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"]          = spec.homepage
  spec.metadata["source_code_uri"]       = "https://github.com/pniemczyk/statesman_scaffold"
  spec.metadata["changelog_uri"]         = "https://github.com/pniemczyk/statesman_scaffold/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

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

  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord",  ">= 7.0", "< 9"
  spec.add_dependency "activesupport", ">= 7.0", "< 9"
  spec.add_dependency "railties",      ">= 7.0", "< 9"
  spec.add_dependency "statesman",     ">= 10.0", "< 13"
end
