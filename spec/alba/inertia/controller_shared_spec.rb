# frozen_string_literal: true

require "spec_helper"

# Exercises `inertia_share` against the real InertiaRails::Controller, with the
# ActionController bits it relies on stubbed out.
RSpec.describe Alba::Inertia::Controller, "inertia_share" do
  let(:base_controller_class) do
    Class.new do
      class << self
        def helper(*)
        end

        def after_action(*, &block)
        end

        def rescue_from(*, &block)
        end

        def before_action(**options, &block)
          share_callbacks << block
        end

        def share_callbacks
          @share_callbacks ||= []
        end
      end

      include InertiaRails::Controller
      include Alba::Inertia::Controller

      def shared_data
        self.class.share_callbacks.each { |callback| instance_exec(&callback) }
        send(:inertia_shared_data)
      end

      def request
        nil
      end

      def session
        {}
      end

      def current_user
        @current_user ||= {id: 1, name: "Test"}
      end

      def user_signed_in?
        true
      end
    end
  end

  let(:controller) { base_controller_class.new }

  around do |example|
    original = InertiaRails.configuration.always_include_errors_hash
    InertiaRails.configure { |config| config.always_include_errors_hash = false }
    example.run
    InertiaRails.configure { |config| config.always_include_errors_hash = original }
  end

  it "shares instance variables assigned in a class-level block" do
    base_controller_class.inertia_share do
      if user_signed_in?
        @user = current_user
        @notifications = 3
      end
    end

    expect(controller.shared_data).to eq(user: {id: 1, name: "Test"}, notifications: 3)
  end

  it "keeps supporting static props and blocks returning a hash" do
    base_controller_class.inertia_share app_name: "Alba"
    base_controller_class.inertia_share { {total_users: 42} }

    expect(controller.shared_data).to eq(app_name: "Alba", total_users: 42)
  end

  it "keeps supporting lambdas assigned to instance variables" do
    base_controller_class.inertia_share do
      @total_users = -> { 42 }
    end

    expect(controller.shared_data[:total_users].call).to eq(42)
  end

  it "does not leak instance variables memoized by controller methods" do
    base_controller_class.inertia_share do
      @name = current_user[:name]
    end

    expect(controller.shared_data).to eq(name: "Test")
  end

  it "supports instance-level sharing from a before_action" do
    controller.inertia_share do
      @user = current_user
    end

    expect(controller.send(:inertia_shared_data)).to eq(user: {id: 1, name: "Test"})
  end

  it "supports instance-level sharing with props" do
    controller.inertia_share(app_name: "Alba")

    expect(controller.send(:inertia_shared_data)).to eq(app_name: "Alba")
  end
end
