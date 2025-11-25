# frozen_string_literal: true

module Alba
  module Inertia
    module Resource
      def self.included(base)
        base.extend(ClassMethods)
      end

      def self.extended(base)
        base.include(self)
      end

      module ClassMethods
        # Override Alba's attribute method to support inertia: option
        #
        # @example
        #   attribute :stats, inertia: :optional do |object|
        #     expensive_calc(object)
        #   end
        #
        #   attribute :data, inertia: { defer: true } do |object|
        #     object.data
        #   end
        def attribute(name, **options, &block)
          extract_inertia_metadata(name, options)
          super
        end

        # Override Alba's association method to support inertia: option
        #
        # @example
        #   has_many :courses, serializer: CourseResource, inertia: { defer: true }
        #   has_one :instructor, serializer: AuthorResource, inertia: :optional
        #   has_many :items, serializer: ItemResource, key: :products, inertia: :optional
        def association(name, condition = nil, **options, &block)
          key = options[:key] || name
          extract_inertia_metadata(key, options)
          super
        end
        alias_method :one, :association
        alias_method :many, :association
        alias_method :has_one, :association
        alias_method :has_many, :association

        # Mark an attribute or association to be wrapped with Inertia props.
        # This does NOT change the attribute definition itself - it only stores metadata
        # that will be used when .to_inertia is called.
        #
        # @example Mark existing association as optional
        #   has_many :courses, serializer: CourseResource
        #   inertia_prop :courses, optional: true
        #
        # @example Defer with merge option
        #   inertia_prop :stats, defer: { merge: true, group: 'analytics' }
        #
        # @example Merge with custom options
        #   inertia_prop :metadata, merge: { match_on: :id, prepend: 'meta_' }
        def inertia_prop(name, **kwargs)
          options = {
            optional: kwargs.delete(:optional) || false,
            defer: kwargs.delete(:defer) || false,
            merge: kwargs.delete(:merge) || false,
            scroll: kwargs.delete(:scroll) || false,
            always: kwargs.delete(:always) || false
          }.select { |_k, v| v.present? }

          inertia_metadata[name] = options.freeze
          auto_typelize_from_inertia(name, options)
        end

        def inertia_metadata
          @inertia_metadata ||= begin
            metadata = {}
            if superclass.respond_to?(:inertia_metadata) && superclass != Alba::Resource
              parent_metadata = superclass.inertia_metadata
              metadata.merge!(parent_metadata) unless parent_metadata.empty?
            end
            metadata
          end
        end

        private

        def extract_inertia_metadata(name, options)
          return unless options.key?(:inertia)

          inertia_opts = parse_inertia_option(options.delete(:inertia))
          inertia_prop(name, **inertia_opts) if inertia_opts.present?
        end

        def parse_inertia_option(value)
          case value
          when Symbol
            # inertia: :optional => { optional: true }
            {value => true}
          when Array
            # inertia: [:optional, :defer] => { optional: true, defer: true }
            value.each_with_object({}) { |key, hash| hash[key] = true }
          when Hash
            # inertia: { defer: true } or { defer: { merge: true } } => unchanged
            value
          else
            {}
          end
        end

        def auto_typelize_from_inertia(name, inertia_opts)
          return unless respond_to?(:typelize)

          should_be_optional = inertia_opts[:optional].present? || inertia_opts[:defer].present?

          typelize(name.to_sym => [optional: true]) if should_be_optional
        end
      end

      def to_inertia
        return {} if object.nil?

        metadata = self.class.inertia_metadata
        result = {}

        self.class._attributes.each do |attr_name, attr_body|
          attr_name_str = attr_name.to_s

          evaluation_block = build_evaluation_block(attr_name, attr_body)

          result[attr_name_str] = if metadata.key?(attr_name)
            PropBuilder.build(evaluation_block, metadata[attr_name], object)
          else
            Alba::Inertia.config.lazy_by_default ? evaluation_block : evaluation_block.call
          end
        end

        result
      end

      private

      def build_evaluation_block(attr_name, attr_body)
        serializer = self
        obj = object

        -> { serializer.send(:fetch_attribute, obj, attr_name, attr_body) }
      end
    end
  end
end
