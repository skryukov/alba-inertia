# frozen_string_literal: true

module Alba
  module Inertia
    class PropBuilder
      ONCE_KEYS = %i[once key expires_in fresh]

      class << self
        def build(evaluation_block, options, object = nil)
          if options[:optional]
            wrap_optional(evaluation_block, options[:optional], object)
          elsif options[:once]
            wrap_once(evaluation_block, options[:once], object)
          elsif options[:defer]
            wrap_defer(evaluation_block, options[:defer], object)
          elsif options[:merge]
            wrap_merge(evaluation_block, options[:merge], object)
          elsif options[:scroll]
            wrap_scroll(evaluation_block, options[:scroll], object)
          elsif options[:always]
            wrap_always(evaluation_block, options[:always], object)
          else
            Alba::Inertia.config.lazy_by_default ? evaluation_block : evaluation_block.call
          end
        end

        private

        def wrap_always(value_block, _opts, _object)
          ::InertiaRails.always(&value_block)
        end

        def wrap_optional(value_block, opts, _object)
          if opts.is_a?(Hash)
            options = opts.slice(*ONCE_KEYS)
            ::InertiaRails.optional(**options, &value_block)
          else
            ::InertiaRails.optional(&value_block)
          end
        end

        def wrap_once(value_block, opts, _object)
          if opts.is_a?(Hash)
            options = opts.slice(*ONCE_KEYS)
            ::InertiaRails.once(**options, &value_block)
          else
            ::InertiaRails.once(&value_block)
          end
        end

        def wrap_defer(value_block, opts, _object)
          if opts.is_a?(Hash)
            options = opts.slice(:group, :deep_merge, :merge, :match_on, *ONCE_KEYS)

            ::InertiaRails.defer(**options, &value_block)
          else
            ::InertiaRails.defer(&value_block)
          end
        end

        def wrap_merge(value_block, opts, _object)
          if opts.is_a?(Hash)
            options = opts.slice(:match_on, *ONCE_KEYS)
            ::InertiaRails.merge(**options, &value_block)
          else
            ::InertiaRails.merge(&value_block)
          end
        end

        def wrap_scroll(value_block, opts, object)
          case opts
          when Symbol
            # scroll: :meta => extract metadata from object[:meta] or object.meta
            metadata = extract_from_object(object, opts)
            ::InertiaRails.scroll(metadata: metadata, &value_block)
          when Proc
            # scroll: -> { |obj| obj.meta } => call proc with object
            metadata = opts.call(object)
            ::InertiaRails.scroll(metadata: metadata, &value_block)
          when Hash
            options = build_scroll_options(opts, object)
            ::InertiaRails.scroll(**options, &value_block)
          when TrueClass
            # scroll: true => auto-detect metadata
            metadata = auto_detect_pagination_metadata(object)
            ::InertiaRails.scroll(metadata: metadata, &value_block)
          else
            raise ArgumentError, "Invalid scroll option. Expected Symbol, Proc, Hash, or true."
          end
        end

        def build_scroll_options(opts, object)
          metadata = case opts[:scroll]
          when Symbol
            extract_from_object(object, opts[:scroll])
          when Proc
            opts[:scroll].call(object)
          else
            opts[:scroll]
          end

          {metadata: metadata}.merge(opts.slice(:wrapper, :page_name, :previous_page, :next_page, :current_page))
        end

        def extract_from_object(object, key)
          if object.respond_to?(:[])
            object[key]
          elsif object.respond_to?(key)
            object.send(key)
          end
        rescue
          nil
        end

        def auto_detect_pagination_metadata(object)
          metadata = extract_from_object(object, :scroll_meta)
          return metadata if metadata

          metadata = extract_from_object(object, :pagy)
          return metadata if metadata

          # Check if object is a Kaminari collection
          return object if defined?(Kaminari) && object.is_a?(Kaminari::PageScopeMethods)

          # If nothing found, raise an error
          raise ArgumentError, "Unable to auto-detect pagination metadata. Please provide metadata explicitly or ensure object has 'scroll_meta', 'pagy' attributes, or is a Kaminari collection."
        end
      end
    end
  end
end
