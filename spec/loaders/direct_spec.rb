# frozen_string_literal: true

require "spec_helper"

RSpec.describe AmsLazyRelationships::Loaders::Direct do
  class ModelA
    attr_reader :id, :model_b

    def initialize(id:, model_b:)
      @id = id
      @model_b = model_b
    end
  end

  class ModelB
    def initialize(id:)
      @id = id
    end
  end

  let(:record) { ModelA.new(id: 1, model_b: model_b) }
  let(:model_b) do
    ModelB.new(id: 2)
  end

  describe "load" do
    let(:loader) do
      described_class.new(:model_b, &:model_b)
    end

    context "when no block passed" do
      let(:loader) do
        described_class.new(:model_b)
      end

      it "simply calls the relationship method" do
        expect(loader.load(record)).to eq(model_b)
      end
    end

    describe "lazy loading" do
      let(:record2) { ModelA.new(id: 3, model_b: model_b2) }
      let(:model_b2) do
        ModelB.new(id: 4)
      end

      it "lazy loads and yields the loaded data" do
        yielded_data = nil
        executions = 0

        block = lambda do |data|
          executions += 1
          yielded_data = data
        end

        # Gather
        called = false

        expect(record).to receive(:model_b).and_wrap_original do |m|
          called = true
          m.call
        end

        expect(called).to eq(false)

        promises = [record, record2].map { |r| loader.load(r, &block) }

        # Lazy eval
        promises.map(&:itself)

        expect(called).to eq(true)

        expect(yielded_data).to match_array([model_b, model_b2])
        expect(executions).to eq(1)
      end

      context "different relationships" do
        let(:loader2) do
          described_class.new(:id)
        end

        it "works fine" do
          expect(loader.load(record)).to eq(model_b)
          expect(loader2.load(record)).to eq(record.id)
        end
      end

      context "different classes" do
        let(:record2) { ModelA.new(id: 3, model_b: model_b2) }
        let(:model_b2) { "x" }

        it "works fine" do
          expect(loader.load(record)).to eq(model_b)
          expect(loader.load(record2)).to eq("x")
        end
      end
    end
  end
end
