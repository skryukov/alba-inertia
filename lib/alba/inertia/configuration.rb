# frozen_string_literal: true

module Alba
  module Inertia
    class Configuration
      # Render with Alba resource class by default
      attr_accessor :default_render

      # Wrap all props in lambdas by default
      attr_accessor :lazy_by_default

      def initialize
        @default_render = true
        @lazy_by_default = true
      end
    end
  end
end
