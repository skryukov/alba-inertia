# frozen_string_literal: true

module Alba
  module Inertia
    module Controller
      private

      def default_render
        Alba::Inertia.config.default_render ? render_inertia : super
      end

      def render_inertia(component = nil, serializer: inertia_serializer_class, locals: view_assigns, **props)
        resource = serializer&.new(locals.symbolize_keys!)
        data = resource.respond_to?(:to_inertia) ? resource.to_inertia : resource.as_json

        render inertia: component || true, props: data || {}, **props
      end

      def inertia_serializer_class
        namespace = self.class.name.deconstantize
        base_name = "#{controller_name}_#{action_name}_resource".classify
        class_name = namespace.present? ? "#{namespace}::#{base_name}" : base_name
        serializer = class_name.safe_constantize || class_name.gsub(/Resource$/, "Serializer").safe_constantize

        handle_missing_serializer(class_name) if serializer.nil?

        serializer
      end

      def handle_missing_serializer(class_name)
        handler = Alba::Inertia.config.on_missing_serializer
        alternative_name = class_name.gsub(/Resource$/, "Serializer")
        message = "Serializer/Resource class not found: #{class_name} or #{alternative_name}"

        case handler
        when :raise
          raise NameError, message
        when :log
          Alba::Inertia.config.logger.warn(message)
        when Proc
          handler.call(class_name, alternative_name)
        end
      end
    end
  end
end
