# frozen_string_literal: true

module Alba
  module Inertia
    class PropBuilder
      class << self
        def build(evaluation_block, options)
          if options[:optional]
            wrap_optional(evaluation_block, options[:optional])
          elsif options[:defer]
            wrap_defer(evaluation_block, options[:defer])
          elsif options[:merge]
            wrap_merge(evaluation_block, options[:merge])
          elsif options[:always]
            wrap_always(evaluation_block, options[:always])
          else
            Alba::Inertia.config.lazy_by_default ? evaluation_block : evaluation_block.call
          end
        end

        private

        def wrap_always(value_block, _opts)
          ::InertiaRails.always(&value_block)
        end

        def wrap_optional(value_block, _opts)
          ::InertiaRails.optional(&value_block)
        end

        def wrap_defer(value_block, opts)
          if opts.is_a?(Hash)
            options = {
              group: opts[:group],
              merge: opts[:merge],
              deep_merge: opts[:deep_merge],
              match_on: opts[:match_on]
            }.compact

            ::InertiaRails.defer(**options, &value_block)
          else
            ::InertiaRails.defer(&value_block)
          end
        end

        def wrap_merge(value_block, opts)
          if opts.is_a?(Hash)
            options = {match_on: opts[:match_on]}.compact
            ::InertiaRails.merge(**options, &value_block)
          else
            ::InertiaRails.merge(&value_block)
          end
        end
      end
    end
  end
end
