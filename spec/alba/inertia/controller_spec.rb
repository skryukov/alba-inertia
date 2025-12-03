# frozen_string_literal: true

require "spec_helper"
require "action_controller"

RSpec.describe Alba::Inertia::Controller do
  let(:controller_class) do
    Class.new do
      include Alba::Inertia::Controller

      attr_accessor :action_name, :rendered_options

      def self.name
        "TestController"
      end

      def controller_name
        "test"
      end

      def render(**options)
        @rendered_options = options
      end

      def view_assigns
        @view_assigns ||= {}
      end

      attr_writer :view_assigns
    end
  end

  let(:controller) { controller_class.new }

  let(:test_resource_class) do
    Class.new do
      include Alba::Resource
      include Alba::Inertia::Resource

      def self.name
        "TestIndexResource"
      end

      attributes :id, :name

      attribute :current_user_id do
        params[:current_user_id]
      end

      attribute :locale do
        params[:locale]
      end
    end
  end

  before do
    stub_const("TestIndexResource", test_resource_class)
    controller.action_name = "index"
  end

  describe "#render_inertia" do
    describe "serializer_params option" do
      it "passes serializer_params to the resource" do
        controller.view_assigns = {id: 1, name: "Test"}

        controller.send(:render_inertia, serializer_params: {current_user_id: 42})
        result = controller.rendered_options

        expect(result[:inertia]).to eq(true)
        # The props should contain the current_user_id from params
        props = result[:props]
        expect(props["current_user_id"]).to be_a(Proc)
        expect(props["current_user_id"].call).to eq(42)
      end

      it "works without serializer_params" do
        controller.view_assigns = {id: 1, name: "Test"}

        controller.send(:render_inertia)
        result = controller.rendered_options

        expect(result[:inertia]).to eq(true)
        props = result[:props]
        expect(props["current_user_id"]).to be_a(Proc)
        expect(props["current_user_id"].call).to be_nil
      end
    end
  end

  describe "#inertia_serializer_params" do
    it "returns empty hash by default" do
      expect(controller.send(:inertia_serializer_params)).to eq({})
    end

    it "can be overridden to provide default params" do
      controller_class.class_eval do
        def inertia_serializer_params
          {current_user_id: 99, locale: "en"}
        end
      end

      expect(controller.send(:inertia_serializer_params)).to eq({current_user_id: 99, locale: "en"})
    end

    it "uses overridden params when rendering" do
      controller_class.class_eval do
        def inertia_serializer_params
          {current_user_id: 99}
        end
      end

      controller.view_assigns = {id: 1, name: "Test"}
      controller.send(:render_inertia)
      result = controller.rendered_options

      props = result[:props]
      expect(props["current_user_id"]).to be_a(Proc)
      expect(props["current_user_id"].call).to eq(99)
    end

    it "merges serializer_params with inertia_serializer_params" do
      controller_class.class_eval do
        def inertia_serializer_params
          {current_user_id: 99, locale: "en"}
        end
      end

      controller.view_assigns = {id: 1, name: "Test"}
      controller.send(:render_inertia, serializer_params: {current_user_id: 123})
      result = controller.rendered_options

      props = result[:props]
      # serializer_params overrides the same key
      expect(props["current_user_id"].call).to eq(123)
      # but preserves other keys from inertia_serializer_params
      expect(props["locale"].call).to eq("en")
    end
  end
end
