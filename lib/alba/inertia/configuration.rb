# frozen_string_literal: true

module Alba
  module Inertia
    class Configuration
      # Render with Alba resource class by default
      attr_accessor :default_render

      # Wrap all props in lambdas by default
      attr_accessor :lazy_by_default

      # How to handle missing serializer/resource classes
      # Options: :ignore, :log, :raise, or a callable (proc/lambda)
      attr_accessor :on_missing_serializer

      # Logger to use when on_missing_serializer is set to :log
      # Defaults to Rails.logger if available
      attr_accessor :logger

      def initialize
        @default_render = true
        @lazy_by_default = true
        @on_missing_serializer = :ignore
        @logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
      end
    end
  end
end
