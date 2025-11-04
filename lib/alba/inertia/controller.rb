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
        class_name = "#{controller_name}_#{action_name}_resource".classify
        class_name.safe_constantize || class_name.gsub(/Resource$/, "Serializer").safe_constantize
      end
    end
  end
end
