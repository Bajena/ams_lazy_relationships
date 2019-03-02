# frozen_string_literal: true

require "spec_helper"
require "active_model_serializers"

AMS_VERSION = Gem::Version.new(ActiveModel::Serializer::VERSION)

RSpec.describe AmsLazyRelationships::Core do
  extend WithArModels

  with_ar_models

  class BaseTestSerializer < ActiveModel::Serializer
    include AmsLazyRelationships::Core

    attributes :id
  end

  let(:user) { User.create! }
  let(:level0_record) do
    user
  end
  let(:serializer) do
    level0_serializer_class.new(level0_record)
  end
  let(:includes) do
    []
  end

  let(:json_api_adapter_class) do
    return "ActiveModelSerializers::Adapter::JsonApi".constantize if AMS_VERSION >= Gem::Version.new("0.10.0.rc5")
    "ActiveModel::Serializer::Adapter::JsonApi".constantize
  end

  let(:json_adapter_class) do
    return "ActiveModelSerializers::Adapter::Json".constantize if AMS_VERSION >= Gem::Version.new("0.10.0.rc5")
    return "ActiveModel::Serializer::Adapter::Json".constantize
  end

  let(:adapter_class) do
    json_adapter_class
  end

  let(:json) do
    adapter_class.new(
      serializer, include: includes
    ).as_json
  end
  let!(:level1_records) do
    (0..2).map do |i|
      BlogPost.create!(user_id: user.id, category_id: level2_records[i].id)
    end
  end
  let!(:level2_records) do
    (0..2).map do
      Category.create!
    end
  end

  let!(:level3_records) do
    (0..2).map do |i|
      CategoryFollower.create!(category_id: level2_records[i].id)
    end
  end

  let(:level0_serializer_class) do
    class Level3Serializer0 < BaseTestSerializer
    end

    class Level2Serializer0 < BaseTestSerializer
      has_many :level3, serializer: Level3Serializer0 do |s|
        s.lazy_level3
      end
      lazy_relationship :level3, loader: AmsLazyRelationships::Loaders::SimpleHasMany.new(
        "CategoryFollower", foreign_key: :category_id
      )
    end

    class Level1Serializer0 < BaseTestSerializer
      lazy_has_one :level2, serializer: Level2Serializer0
      lazy_relationship :level2, loader: AmsLazyRelationships::Loaders::SimpleBelongsTo.new(
        "Category"
      )
    end

    class Level0Serializer0 < BaseTestSerializer
      has_many :level1, serializer: Level1Serializer0 do |s|
        s.lazy_level1
      end
      lazy_relationship :level1, loader: AmsLazyRelationships::Loaders::Association.new(
        "User", :blog_posts
      )
    end

    Level0Serializer0
  end

  it "defines a lazy_ instance method" do
    expect(serializer).to respond_to(:lazy_level1)
  end

  describe "json_api" do
    let(:adapter_class) do
      json_api_adapter_class
    end

    let(:included_level1_ids) do
      json[:included].map { |i| i[:id].to_i }
    end
    let(:relationship_level2_ids) do
      json[:included].map do |i|
        i.dig(:relationships, :level2, :data, :id).try(:to_i)
      end
    end
    let(:relationship_level1_ids) do
      json.dig(:data, :relationships, :level1, :data).map do |i|
        i[:id].to_i
      end
    end

    context "0 level nesting requested" do
      it "lazy evaluates up to level 1" do
        expect do
          expect do
            json
          end.to make_database_queries(count: 1, matching: "blog_posts") # Needed to render ids
        end.not_to make_database_queries(matching: "categories")
      end

      it "renders correct results" do
        expect(relationship_level1_ids).to match_array(level1_records.map(&:id))
      end
    end

    context "1 level nesting requested" do
      let(:includes) { %w(level1) }

      it "lazy evaluates up to level 1" do
        expect do
          expect do
            expect do
              json
            end.to make_database_queries(count: 1, matching: "blog_posts")
          end.to make_database_queries(count: 1, matching: "categories") # Needed to render ids
        end.not_to make_database_queries(matching: "category_followers")
      end

      it "renders correct results" do
        expect(included_level1_ids).to match_array(level1_records.map(&:id))
        expect(relationship_level2_ids).to match_array(level2_records.map(&:id))
      end
    end

    context "2 level nesting requested" do
      let(:includes) { ["level1.level2"] }

      it "lazy evaluates up to level 2" do
        expect do
          expect do
            expect do
              json
            end.to make_database_queries(count: 1, matching: "blog_posts")
          end.to make_database_queries(count: 1, matching: "categories")
        end.to make_database_queries(count: 1, matching: "category_followers") # Needed to render ids
      end

      context "when an association returns nil" do
        before do
          record = level1_records.first

          record.category = nil
          record.save(validate: false)
        end

        it "renders nil correctly" do
          null_relationship_data =
            json.dig(:included).first[:relationships][:level2][:data]
          expect(null_relationship_data).to eq(nil)
        end

        it "prevents N+1 queries" do
          expect do
            expect do
              expect do
                json
              end.to make_database_queries(count: 1, matching: "blog_posts")
            end.to make_database_queries(count: 1, matching: "categories")
          end.to make_database_queries(count: 1, matching: "category_followers") # Needed to render ids
        end
      end
    end

    context "when relationship exceeds max lazy nesting levels" do
      let(:includes) { ["level1.level2"] }

      before do
        stub_const("AmsLazyRelationships::Core::Evaluation::LAZY_NESTING_LEVELS", 2)
      end

      it "doesn't lazy load deeper relationships" do
        expect do
          expect do
            expect do
              json
            end.to make_database_queries(count: 1, matching: "blog_posts")
          end.to make_database_queries(count: 1, matching: "categories")
        end.to make_database_queries(count: 3, matching: "category_followers")
      end
    end
  end

  describe "json" do
    let(:included_level1_ids) do
      json.dig(:user, :level1).map { |i| i[:id].to_i }
    end

    context "0 level nesting requested" do
      it "lazy evaluates up to level 1" do
        expect do
          json
        end.not_to make_database_queries(matching: "blog_posts")
      end

      it "renders correct results" do
        expect(json.dig(:user, :id)).to eq(level0_record.id)
      end
    end

    context "1 level nesting requested" do
      let(:includes) { %w(level1) }

      it "lazy evaluates up to level 1" do
        expect do
          expect do
            json
          end.to make_database_queries(count: 1, matching: "blog_posts")
        end.not_to make_database_queries(matching: "categories")
      end

      it "renders correct results" do
        expect(included_level1_ids).to match_array(level1_records.map(&:id))
      end
    end

    context "2 level nesting requested" do
      let(:includes) { ["level1.level2"] }

      it "lazy evaluates up to level 2" do
        expect do
          expect do
            expect do
              json
            end.to make_database_queries(count: 1, matching: "blog_posts")
          end.to make_database_queries(count: 1, matching: "categories")
        end.not_to make_database_queries(matching: "category_followers")
      end

      context "when an association returns nil" do
        before do
          record = level1_records.first

          record.category = nil
          record.save(validate: false)
        end

        it "renders nil correctly" do
          null_relationship_data = json.dig(:user, :level1).first[:level2]
          expect(null_relationship_data).to eq(nil)
        end

        it "prevents N+1 queries" do
          expect do
            expect do
              expect do
                json
              end.to make_database_queries(count: 1, matching: "blog_posts")
            end.to make_database_queries(count: 1, matching: "categories")
          end.not_to make_database_queries(matching: "category_followers")
        end
      end
    end

    context "when relationship exceeds max lazy nesting levels" do
      let(:includes) { ["level1.level2"] }

      before do
        stub_const("AmsLazyRelationships::Core::Evaluation::LAZY_NESTING_LEVELS", 1)
      end

      it "doesn't lazy load deeper relationships" do
        expect do
          expect do
            expect do
              json
            end.to make_database_queries(count: 1, matching: "blog_posts")
          end.to make_database_queries(count: 3, matching: "categories")
        end.not_to make_database_queries(matching: "category_followers")
      end
    end
  end

  describe "lazy_has_many" do
    let(:includes) { "level1" }

    let(:level0_serializer_class) do
      class Level1Serializer3 < BaseTestSerializer
      end

      class Level0Serializer3 < BaseTestSerializer
        lazy_has_many :level1,
                      serializer: Level1Serializer3,
                      loader: AmsLazyRelationships::Loaders::Association.new(
                        "Account", :blog_posts
                      )
      end

      Level0Serializer3
    end

    it "provides a convenience method for lazy relationships" do
      ids = json.dig(:user, :level1).map { |x| x[:id].to_i }
      expect(ids).to match_array(level1_records.map(&:id))
    end
  end

  describe "lazy_has_one" do
    let(:includes) { "level1" }
    let(:comment) { Comment.create!(user_id: user.id) }
    let(:serializer) do
      level0_serializer_class.new(comment)
    end
    let(:level0_serializer_class) do
      class Level1Serializer4 < BaseTestSerializer
      end

      class Level0Serializer4 < BaseTestSerializer
        lazy_has_one :level1,
                     serializer: Level1Serializer4,
                     loader: AmsLazyRelationships::Loaders::Association.new(
                       "Comment", :user
                     )
      end

      Level0Serializer4
    end

    it "provides a convenience method for lazy relationships" do
      id = json.dig(:comment, :level1, :id).to_i
      expect(id).to eq(comment.user_id)
    end
  end

  describe "lazy_belongs_to" do
    let(:includes) { "level1" }
    let(:comment) { Comment.create!(user_id: user.id) }
    let(:serializer) do
      level0_serializer_class.new(comment)
    end
    let(:level0_serializer_class) do
      class Level1Serializer5 < BaseTestSerializer
      end

      class Level0Serializer5 < BaseTestSerializer
        lazy_belongs_to :level1,
                     serializer: Level1Serializer5,
                     loader: AmsLazyRelationships::Loaders::Association.new(
                       "Comment", :user
                     )
      end

      Level0Serializer5
    end

    it "provides a convenience method for lazy relationships" do
      id = json.dig(:comment, :level1, :id).to_i
      expect(id).to eq(comment.user_id)
    end

    describe "passing block to lazy_belongs_to" do
      let(:includes) { "level1" }
      let(:level0_serializer_class) do
        class Level1Serializer6 < BaseTestSerializer
          attributes :name
        end

        class Level0Serializer6 < BaseTestSerializer
          lazy_belongs_to :level1,
                          serializer: Level1Serializer6,
                          loader: AmsLazyRelationships::Loaders::Association.new(
                            "Comment", :user
                          ) do |serializer|
            if object.user_id
              ll1 = serializer.lazy_level1
              ll1.name = "x"
              ll1
            end
          end
        end

        Level0Serializer6
      end

      it "yields serializer object and lets to use 'object' method" do
        id = json.dig(:comment, :level1, :id).to_i
        expect(id).to eq(comment.user_id)
        serialized_name = json.dig(:comment, :level1, :name)
        expect(serialized_name).to eq("x")
      end
    end
  end

  describe "loader option" do
    let(:level0_serializer_class) do
      class Level1Serializer1 < BaseTestSerializer
      end

      class Level0Serializer1 < BaseTestSerializer
        has_many :level1, serializer: Level1Serializer1
        lazy_relationship :blog_posts

        def level1
          lazy_blog_posts
        end
      end

      Level0Serializer1
    end

    it "uses the Loaders::Association by default" do
      expect { json }.not_to raise_error
    end
  end

  describe "load_for option" do
    class UserDecorator
      alias :read_attribute_for_serialization :send

      def initialize(object)
        @object = object
      end

      attr_reader :object

      delegate :id, :blog_posts, to: :object

      def self.model_name
        @_model_name ||= User.model_name
      end
    end

    let(:level0_record) do
      UserDecorator.new(user)
    end

    let!(:level0_serializer_class) do
      class Level1Serializer2 < BaseTestSerializer
      end

      class Level0Serializer2 < BaseTestSerializer
        has_many :level1, serializer: Level1Serializer2 do |s|
          s.lazy_level1
        end
        lazy_relationship :level1,
                          loader: AmsLazyRelationships::Loaders::Association.new(
                            "User", :blog_posts
                          ),
                          load_for: :object

        def level1
          lazy_blog_posts
        end
      end

      Level0Serializer2
    end

    it "executes the loader on the object pointed by the symbol" do
      expect(level0_record).
        to receive(:object).at_least(:once).and_call_original
      expect { json }.not_to raise_error
    end
  end

  describe "inheritance of lazy relationships" do
    let(:includes) { ["blog_posts", "comments"] }
    let(:level1_serializer) do
      Class.new(BaseTestSerializer)
    end
    let(:base_level0_serializer) do
      relationship_serializer = level1_serializer

      superbase = Class.new(BaseTestSerializer) do
        has_many :blog_posts, serializer: relationship_serializer, &:lazy_blog_posts
        lazy_relationship :blog_posts, loader: AmsLazyRelationships::Loaders::Association.new(
          "User", :blog_posts
        )
      end

      Class.new(superbase) do
        has_many :comments, serializer: relationship_serializer, &:lazy_comments
        lazy_relationship :comments, loader: AmsLazyRelationships::Loaders::Association.new(
          "User", :comments
        )
      end
    end

    let(:level0_serializer_class) do
      Class.new(base_level0_serializer)
    end

    it "keeps the lazy relationships in inherited serializers" do
      expect(json[:user][:blog_posts]).not_to be_nil
      expect(json[:user][:comments]).not_to be_nil
    end
  end
end
