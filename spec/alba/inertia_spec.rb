# frozen_string_literal: true

require "spec_helper"

RSpec.describe Alba::Inertia::Resource do
  let(:test_resource_class) do
    Class.new do
      include Alba::Resource
      include Alba::Inertia::Resource

      def self.name
        "TestResource"
      end
    end
  end

  describe ".inertia_prop" do
    it "marks existing attribute for wrapping" do
      test_resource_class.attributes :name
      test_resource_class.inertia_prop :name, optional: true

      resource = test_resource_class.new({name: "Test"})

      # as_json returns normal value
      expect(resource.as_json["name"]).to eq("Test")

      # to_inertia wraps it
      expect(resource.to_inertia["name"]).to be_a(InertiaRails::OptionalProp)
    end

    it "stores metadata with hash options" do
      test_resource_class.inertia_prop :data, defer: {merge: true}

      expect(test_resource_class.inertia_metadata[:data]).to eq(defer: {merge: true})
    end
  end

  describe "#to_inertia" do
    it "returns empty hash for nil object" do
      resource = test_resource_class.new(nil)
      result = resource.to_inertia

      expect(result).to eq({})
    end

    it "returns lazy procs for attributes without metadata" do
      test_resource_class.attributes :name

      resource = test_resource_class.new({name: "Test"})
      result = resource.to_inertia

      # Regular attributes are wrapped in procs for lazy evaluation
      expect(result["name"]).to be_a(Proc)
      expect(result["name"].call).to eq("Test")
    end

    it "wraps optional props" do
      test_resource_class.attributes :name
      test_resource_class.inertia_prop :name, optional: true

      resource = test_resource_class.new({name: "Test"})
      result = resource.to_inertia

      expect(result["name"]).to be_a(InertiaRails::OptionalProp)
    end

    it "wraps defer props with options" do
      test_resource_class.attributes :data
      test_resource_class.inertia_prop :data, defer: {merge: true, group: "test"}

      resource = test_resource_class.new({data: [1, 2, 3]})
      result = resource.to_inertia

      expect(result["data"]).to be_a(InertiaRails::DeferProp)
    end

    it "wraps merge props with options" do
      test_resource_class.attributes :meta
      test_resource_class.inertia_prop :meta, merge: {match_on: :id}

      resource = test_resource_class.new({meta: {id: 1}})
      result = resource.to_inertia

      expect(result["meta"]).to be_a(InertiaRails::MergeProp)
    end

    it "wraps always props" do
      test_resource_class.attributes :important
      test_resource_class.inertia_prop :important, always: true

      resource = test_resource_class.new({important: "data"})
      result = resource.to_inertia

      expect(result["important"]).to be_a(InertiaRails::AlwaysProp)
    end

    it "wraps attributes differently based on metadata" do
      test_resource_class.attributes :id, :name
      test_resource_class.inertia_prop :name, optional: true

      resource = test_resource_class.new({id: 1, name: "Test"})
      result = resource.to_inertia

      # id is wrapped in lazy proc (no metadata)
      expect(result["id"]).to be_a(Proc)
      expect(result["id"].call).to eq(1)

      # name is wrapped in InertiaRails prop (has metadata)
      expect(result["name"]).to be_a(InertiaRails::OptionalProp)
    end
  end

  describe "#as_json" do
    it "returns normal Alba serialization without wrapping" do
      test_resource_class.attributes :id, :name
      test_resource_class.inertia_prop :name, optional: true
      test_resource_class.attribute :count, inertia: :defer do |obj|
        obj[:value]
      end

      resource = test_resource_class.new({id: 1, name: "Test", value: 42})
      result = resource.as_json

      # All attributes are normal values, not wrapped
      expect(result["id"]).to eq(1)
      expect(result["name"]).to eq("Test")
      expect(result["count"]).to eq(42)

      # No InertiaRails props
      expect(result.values).to all(satisfy { |v| !v.is_a?(InertiaRails::BaseProp) })
    end
  end

  describe ".inertia_metadata" do
    it "returns empty metadata when no props are defined" do
      expect(test_resource_class.inertia_metadata).to be_empty
    end

    it "accumulates metadata from multiple definitions" do
      test_resource_class.inertia_prop :field1, optional: true
      test_resource_class.attribute :field2, inertia: :defer do |obj|
        obj[:value]
      end

      expect(test_resource_class.inertia_metadata.keys).to contain_exactly(:field1, :field2)
    end

    it "inherits metadata from parent class" do
      parent_class = Class.new do
        include Alba::Resource
        include Alba::Inertia::Resource

        attributes :parent_field
        inertia_prop :parent_field, optional: true
      end

      child_class = Class.new(parent_class) do
        attributes :child_field
        inertia_prop :child_field, defer: true
      end

      expect(child_class.inertia_metadata.keys).to contain_exactly(:parent_field, :child_field)
      expect(child_class.inertia_metadata[:parent_field]).to eq(optional: true)
      expect(child_class.inertia_metadata[:child_field]).to eq(defer: true)
    end

    it "allows child to override parent metadata" do
      parent_class = Class.new do
        include Alba::Resource
        include Alba::Inertia::Resource

        attributes :field
        inertia_prop :field, optional: true
      end

      child_class = Class.new(parent_class) do
        inertia_prop :field, defer: true
      end

      # Child's metadata should override parent's
      expect(child_class.inertia_metadata[:field]).to eq(defer: true)
    end
  end

  describe "inertia: option on attribute" do
    it "supports symbol format" do
      test_resource_class.attribute :name, inertia: :optional do |obj|
        obj[:name]
      end

      resource = test_resource_class.new({name: "Test"})
      result = resource.to_inertia

      expect(result["name"]).to be_a(InertiaRails::OptionalProp)
      expect(test_resource_class.inertia_metadata[:name]).to eq(optional: true)
    end

    it "supports hash format" do
      test_resource_class.attribute :stats, inertia: {defer: true} do |obj|
        obj[:data]
      end

      resource = test_resource_class.new({data: {foo: "bar"}})
      result = resource.to_inertia

      expect(result["stats"]).to be_a(InertiaRails::DeferProp)
    end

    it "supports hash with nested options" do
      test_resource_class.attribute :analytics, inertia: {defer: {merge: true, group: "test"}} do |obj|
        obj[:analytics]
      end

      resource = test_resource_class.new({analytics: [1, 2, 3]})
      result = resource.to_inertia

      expect(result["analytics"]).to be_a(InertiaRails::DeferProp)
      expect(test_resource_class.inertia_metadata[:analytics]).to eq(defer: {merge: true, group: "test"})
    end

    it "supports array format" do
      test_resource_class.attribute :data, inertia: [:optional, :defer] do |obj|
        obj[:data]
      end

      resource = test_resource_class.new({data: "test"})
      result = resource.to_inertia

      # First matching option should be used (optional)
      expect(result["data"]).to be_a(InertiaRails::OptionalProp)
      expect(test_resource_class.inertia_metadata[:data]).to eq(optional: true, defer: true)
    end
  end

  describe "inertia: option on association" do
    let(:nested_resource_class) do
      Class.new do
        include Alba::Resource

        attributes :id, :name
      end
    end

    it "supports symbol format on has_many" do
      test_resource_class.has_many :items, serializer: nested_resource_class, inertia: :optional

      resource = test_resource_class.new({items: [{id: 1, name: "Item 1"}]})
      result = resource.to_inertia

      expect(result["items"]).to be_a(InertiaRails::OptionalProp)
    end

    it "supports hash format on has_one" do
      test_resource_class.has_one :profile, serializer: nested_resource_class, inertia: {defer: true}

      resource = test_resource_class.new({profile: {id: 1, name: "Profile"}})
      result = resource.to_inertia

      expect(result["profile"]).to be_a(InertiaRails::DeferProp)
    end

    it "works with key option" do
      test_resource_class.has_many :items, serializer: nested_resource_class, key: :products, inertia: :optional

      resource = test_resource_class.new({items: [{id: 1, name: "Item 1"}]})
      result = resource.to_inertia

      expect(result["products"]).to be_a(InertiaRails::OptionalProp)
    end
  end
end
