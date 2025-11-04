# frozen_string_literal: true

require_relative "inertia/version"
require_relative "inertia/configuration"
require_relative "inertia/controller"
require_relative "inertia/prop_builder"
require_relative "inertia/resource"

module Alba
  module Inertia
    class << self
      attr_accessor :configuration
    end

    def self.configure
      self.configuration ||= Configuration.new
      yield(configuration)
    end

    def self.config
      self.configuration ||= Configuration.new
    end

    def self.reset_configuration!
      self.configuration = Configuration.new
    end
  end
end
