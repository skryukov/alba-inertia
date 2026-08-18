# frozen_string_literal: true

module Alba
  module Inertia
    # Adds instance variable support to `inertia_share` blocks.
    #
    # Instead of returning a hash, a shared block may assign instance
    # variables, mirroring how alba-inertia controllers pass data to
    # resources:
    #
    #   inertia_share do
    #     @user = current_user&.as_json(only: [:id, :name])
    #     @total_users = -> { User.count }
    #   end
    #
    # The block is evaluated by a Collector standing in for the controller:
    # method calls are delegated to the controller, while assignments stay on
    # the collector and are turned into shared props (`@user` => `user`).
    module SharedProps
      # Instance variables that are never exposed as props.
      INTERNAL_IVAR = /\A@_/

      class << self
        # Wraps a shared block so that InertiaRails receives a block returning
        # a props hash. The wrapper is `instance_exec`ed on the controller.
        def wrap(block)
          proc { ::Alba::Inertia::SharedProps.collect(self, &block) }
        end

        # @return [Hash] props assigned as instance variables inside the block,
        #   falling back to the hash returned by the block
        def collect(controller, &block)
          Collector.new(controller).collect(&block)
        end
      end

      # Stands in for the controller while a shared block is evaluated.
      class Collector < ::BasicObject
        IVARS = ::Kernel.instance_method(:instance_variables)
        IVAR_GET = ::Kernel.instance_method(:instance_variable_get)
        IVAR_SET = ::Kernel.instance_method(:instance_variable_set)

        def initialize(controller)
          @__controller__ = controller
          @__snapshot__ = {}

          # Copy the controller's instance variables over, so the block can
          # read them. They only become props if the block reassigns them.
          IVARS.bind_call(controller).each do |name|
            value = IVAR_GET.bind_call(controller, name)
            @__snapshot__[name] = value
            IVAR_SET.bind_call(self, name, value)
          end
        end

        # Instance variables win over the return value: `@user = ...` as the
        # last expression of a block returns the assigned value, so a block
        # assigning instance variables never uses its return value as props.
        def collect(&block)
          result = instance_exec(&block)
          props = assigned_props
          return props unless props.empty?

          result.is_a?(::Hash) ? result : props
        end

        def method_missing(name, *args, **kwargs, &block)
          @__controller__.__send__(name, *args, **kwargs, &block)
        end

        def respond_to_missing?(name, include_private = false)
          @__controller__.respond_to?(name, true)
        end

        private

        def assigned_props
          IVARS.bind_call(self).each_with_object({}) do |name, props|
            next if INTERNAL_IVAR.match?(name.to_s)

            value = IVAR_GET.bind_call(self, name)
            next if @__snapshot__.key?(name) && @__snapshot__[name].equal?(value)

            props[name.to_s.delete_prefix("@").to_sym] = value
          end
        end
      end
    end
  end
end
