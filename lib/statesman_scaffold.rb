# frozen_string_literal: true

require_relative "statesman_scaffold/version"
require_relative "statesman_scaffold/concern"
require_relative "statesman_scaffold/generator"
require_relative "statesman_scaffold/installer"

module StatesmanScaffold
  class Error < StandardError; end
end

require "statesman_scaffold/railtie" if defined?(Rails::Railtie)
