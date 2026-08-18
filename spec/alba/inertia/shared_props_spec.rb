# frozen_string_literal: true

require "spec_helper"

RSpec.describe Alba::Inertia::SharedProps do
  let(:controller_class) do
    Class.new do
      def initialize
        @account = "Acme"
      end

      def user_signed_in?
        true
      end

      def current_user
        @current_user ||= {id: 1, name: "Test"}
      end

      private

      def unread_notifications_count
        3
      end
    end
  end

  let(:controller) { controller_class.new }

  def collect(&block)
    described_class.collect(controller, &block)
  end

  describe ".collect" do
    it "turns instance variables assigned in the block into props" do
      props = collect do
        @user = {id: 1}
        @notifications = 3
      end

      expect(props).to eq(user: {id: 1}, notifications: 3)
    end

    it "delegates method calls to the controller" do
      props = collect do
        if user_signed_in?
          @user = current_user
          @notifications = unread_notifications_count
        end
      end

      expect(props).to eq(user: {id: 1, name: "Test"}, notifications: 3)
    end

    it "does not expose instance variables memoized by delegated methods" do
      props = collect { @name = current_user[:name] }

      expect(props).to eq(name: "Test")
      expect(controller.instance_variable_get(:@current_user)).to eq(id: 1, name: "Test")
    end

    it "reads controller instance variables without exposing them" do
      props = collect { @account_name = @account.downcase }

      expect(props).to eq(account_name: "acme")
    end

    it "exposes controller instance variables reassigned by the block" do
      props = collect { @account = "Globex" }

      expect(props).to eq(account: "Globex")
    end

    it "keeps assignments out of the controller" do
      collect { @user = {id: 1} }

      expect(controller.instance_variables).not_to include(:@user)
      expect(controller.instance_variable_get(:@account)).to eq("Acme")
    end

    it "skips internal instance variables" do
      props = collect do
        @_internal = "hidden"
        @user = {id: 1}
      end

      expect(props).to eq(user: {id: 1})
    end

    it "keeps lambdas and Inertia props as values" do
      props = collect do
        @total_users = -> { 42 }
        @stats = InertiaRails.defer { 1 }
      end

      expect(props[:total_users].call).to eq(42)
      expect(props[:stats]).to be_a(InertiaRails::DeferProp)
    end

    it "supports blocks returning a hash" do
      props = collect { {user: {id: 1}} }

      expect(props).to eq(user: {id: 1})
    end

    it "ignores the return value when instance variables are assigned" do
      props = collect do
        @notifications = 3
        @user = {id: 1}
      end

      expect(props).to eq(user: {id: 1}, notifications: 3)
    end

    it "returns an empty hash when the block returns a non-hash value" do
      props = collect { nil }

      expect(props).to eq({})
    end
  end

  describe ".wrap" do
    it "returns a block evaluating in the controller context" do
      wrapped = described_class.wrap(proc { @user = current_user })

      expect(controller.instance_exec(&wrapped)).to eq(user: {id: 1, name: "Test"})
    end
  end
end
