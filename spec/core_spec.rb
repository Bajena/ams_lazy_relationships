# frozen_string_literal: true

require "spec_helper"

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
      json[:included].map { |i| i[:id] }
    end
    let(:relationship_level2_ids) do
      json[:included].map do |i|
        i.dig(:relationships, :level2, :data, :id)
      end
    end
    let(:relationship_level1_ids) do
      json.dig(:data, :relationships, :level1, :data).map do |i|
        i[:id]
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

      context "association populated by accepts_nested_attributes_for" do
        let(:user) { User.create!(blog_posts_attributes: [{title: 'Foo'}]) }
        let(:level1_records) { [] }

        it "avoids the duplication of associated records" do
          expect(relationship_level1_ids.size).to eq(1)
        end
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
      json.dig(:user, :level1).map { |i| i[:id] }
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
      ids = json.dig(:user, :level1).map { |x| x[:id] }
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

        attribute :conditional_level1 do
          lazy_level1 ? 'exists' : 'missing'
        end

        attribute :safe_navigated_level1 do
          lazy_level1&.id
        end
      end

      Level0Serializer4
    end

    it "provides a convenience method for lazy relationships" do
      id = json.dig(:comment, :level1, :id)
      expect(id).to eq(comment.user_id)
    end

    it "realizes the presence of relationship object through trivial condition" do
      conditional_level1 = json.dig(:comment, :conditional_level1)
      expect(conditional_level1).to eq('exists')
    end

    it "realizes the presence of relationship object through safe navigation" do
      conditional_level1 = json.dig(:comment, :safe_navigated_level1)
      expect(conditional_level1).to eq(user.id)
    end

    context 'missing level1' do
      let(:comment) { Comment.create!(user_id: nil) }

      it "realizes the absence of relationship object through trivial condition" do
        conditional_level1 = json.dig(:comment, :conditional_level1)
        expect(conditional_level1).to eq('missing')
      end

      it "realizes the absence of relationship object through safe navigation" do
        conditional_level1 = json.dig(:comment, :safe_navigated_level1)
        expect(conditional_level1).to be_nil
      end
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

        attribute :conditional_level1 do
          lazy_level1 ? 'exists' : 'missing'
        end

        attribute :safe_navigated_level1 do
          lazy_level1&.id
        end
      end

      Level0Serializer5
    end

    it "provides a convenience method for lazy relationships" do
      id = json.dig(:comment, :level1, :id)
      expect(id).to eq(comment.user_id)
    end

    it "realizes the presence of relationship object through trivial condition" do
      conditional_level1 = json.dig(:comment, :conditional_level1)
      expect(conditional_level1).to eq('exists')
    end

    it "realizes the presence of relationship object through safe navigation" do
      conditional_level1 = json.dig(:comment, :safe_navigated_level1)
      expect(conditional_level1).to eq(user.id)
    end

    context 'missing level1' do
      let(:comment) { Comment.create!(user_id: nil) }

      it "realizes the absence of relationship object through trivial condition" do
        conditional_level1 = json.dig(:comment, :conditional_level1)
        expect(conditional_level1).to eq('missing')
      end

      it "realizes the absence of relationship object through safe navigation" do
        conditional_level1 = json.dig(:comment, :safe_navigated_level1)
        expect(conditional_level1).to be_nil
      end
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
        id = json.dig(:comment, :level1, :id)
        expect(id).to eq(comment.user_id)
        serialized_name = json.dig(:comment, :level1, :name)
        expect(serialized_name).to eq("x")
      end
    end
  end

  describe "loader option" do
    let(:level0_serializer_class) do
      class Level1Serializer7 < BaseTestSerializer
      end

      class Level0Serializer7 < BaseTestSerializer
        has_many :level1, serializer: Level1Serializer7
        lazy_relationship :blog_posts

        def level1
          lazy_blog_posts
        end
      end

      Level0Serializer7
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
      class Level1Serializer8 < BaseTestSerializer
      end

      class Level0Serializer8 < BaseTestSerializer
        has_many :level1, serializer: Level1Serializer8 do |s|
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

      Level0Serializer8
    end

    it "executes the loader on the object pointed by the symbol" do
      expect(level0_record).
        to receive(:object).at_least(:once).and_call_original
      expect { json }.not_to raise_error
    end
  end

  describe "inheritance of lazy relationships" do
    let(:level0_serializer_class) do
      class Level2Serializer9 < BaseTestSerializer
      end

      class Level1Serializer9 < BaseTestSerializer
        lazy_has_one :level2, serializer: Level2Serializer9
        lazy_relationship :level2, loader: AmsLazyRelationships::Loaders::SimpleBelongsTo.new(
          "Category"
        )
      end

      class Level1Serializer9Inherited < Level1Serializer9
      end

      class Level0Serializer9 < BaseTestSerializer
        has_many :level1, serializer: Level1Serializer9Inherited do |s|
          s.lazy_level1
        end
        lazy_relationship :level1, loader: AmsLazyRelationships::Loaders::Association.new(
          "User", :blog_posts
        )
      end

      Level0Serializer9
    end

    let(:includes) { ["level1.level2"] }

    it "copies relationships to inherited serializer" do
      expect do
        expect do
          json
        end.to make_database_queries(count: 1, matching: "blog_posts")
      end.to make_database_queries(count: 1, matching: "categories")
    end
  end

  shared_examples "lazy loader for nested serializer" do
    let(:adapter_class) { json_api_adapter_class }
    let(:json) do
      JSON.parse(
        adapter_class.new(
          serializer, include: includes
        ).to_json
      )
    end
    let(:includes) { ["blog_posts.category"] }
    let(:blog_post_payload) { json['included'].detect { |obj| obj['type'] == 'blog_posts' } }
    let(:category_payload) { json['included'].detect { |obj| obj['type'] == 'categories' } }

    it "avoids N+1 still" do
      expect { json }
        .to make_database_queries(count: 1, matching: "blog_posts")
        .and make_database_queries(count: 1, matching: "categories")
        .and make_database_queries(count: 1, matching: "category_followers")
    end

    it "searches for nested serializer in same manner as ActiveModelSerializer do" do
      blog_post_attributes = blog_post_payload['attributes'].keys
      expect(blog_post_attributes).to match_array(['title'])

      category_attributes = category_payload['attributes'].keys
      expect(category_attributes).to match_array(%w[created_at])
    end

    it "does not fail if nested serializer is missing" do
      category_follower_attributes = category_payload.dig('relationships', 'category_followers', 'data', 0).keys
      expect(category_follower_attributes).to match_array(%w[id category_id created_at updated_at])
    end
  end

  describe "straightforward serializers lookup" do
    let(:level0_serializer_class) do
      module Serializer10
        class UserSerializer < BaseTestSerializer
          lazy_has_many :blog_posts
        end

        class UserSerializer::BlogPostSerializer < BaseTestSerializer
          lazy_belongs_to :category

          attributes :title
        end

        class UserSerializer::BlogPostSerializer::CategorySerializer < BaseTestSerializer
          attributes :created_at

          lazy_has_many :category_followers
        end
      end

      Serializer10::UserSerializer
    end

    include_examples "lazy loader for nested serializer"
  end

  describe "customized serializers lookup" do
    next unless AMS_VERSION >= Gem::Version.new("0.10.3")

    let(:level0_serializer_class) do
      module Serializer11
        class UserSerializer < BaseTestSerializer
          lazy_has_many :blog_posts
        end

        class BlogPostSerializer < BaseTestSerializer
          lazy_belongs_to :category

          attributes :title
        end

        class CategorySerializer < BaseTestSerializer
          attributes :created_at

          lazy_has_many :category_followers
        end
      end

      Serializer11::UserSerializer
    end

    around do |example|
      serializer_lookup_chain = ActiveModelSerializers.config.serializer_lookup_chain
      custom_serializer_lookup = -> (resource_class, serializer_class, _namespace) {
        "#{serializer_class.name.deconstantize}::#{resource_class.name}Serializer"
      }
      ActiveModelSerializers.config.serializer_lookup_chain = [custom_serializer_lookup] + serializer_lookup_chain

      example.run

      ActiveModelSerializers.config.serializer_lookup_chain = serializer_lookup_chain
    end

    include_examples "lazy loader for nested serializer"
  end

  describe '#lazy_dig' do
    context 'collection association' do
      let(:level0_serializer_class) do
        module Serializer12
          class CategorySerializer < BaseTestSerializer
            lazy_has_many :category_followers
          end

          class BlogPostSerializer < BaseTestSerializer
            lazy_belongs_to :category, serializer: CategorySerializer
          end

          class UserSerializer < BaseTestSerializer
            lazy_has_many :blog_posts, serializer: BlogPostSerializer
          end
        end

        Serializer12::UserSerializer
      end

      it 'does not fire unnecessary queries' do
        expect { json }
          .to make_database_queries(count: 0, matching: 'blog_posts')
      end

      context '1 level dig' do
        context 'success finding' do
          let(:level0_serializer_class) do
            Class.new(super()) do
              attribute(:blog_post_ids) { lazy_dig(:blog_posts).map(&:id) }
            end
          end

          it 'prevents N+1 queries' do
            expect { json }
              .to make_database_queries(count: 1, matching: 'blog_posts')
              .and make_database_queries(count: 0, matching: 'categories')
          end

          it 'digs association properly' do
            json_blog_post_ids = json.dig(:user, :blog_post_ids)
            expect(json_blog_post_ids).to match_array(level1_records.map(&:id))
          end
        end

        context 'misspelled association' do
          let(:level0_serializer_class) do
            Class.new(super()) do
              attribute(:blog_post_ids) { lazy_dig(:misspelled_blog_posts).map(&:id) }

              class << self
                delegate :name, to: :superclass
              end
            end
          end

          it 'raises ArgumentError' do
            expect { json }
              .to raise_error(ArgumentError, /Undefined lazy 'misspelled_blog_posts' relationship for 'Serializer12::UserSerializer' serializer/)
          end
        end
      end

      context '2 level dig' do
        context 'success finding' do
          let(:level0_serializer_class) do
            Class.new(super()) do
              attribute(:category_ids) { lazy_dig(:blog_posts, :category).map(&:id) }
            end
          end

          it 'prevents N+1 queries' do
            expect { json }
              .to make_database_queries(count: 1, matching: 'blog_posts')
              .and make_database_queries(count: 1, matching: 'categories')
              .and make_database_queries(count: 0, matching: 'category_followers')
          end

          it 'digs association properly' do
            json_category_ids = json.dig(:user, :category_ids)
            expect(json_category_ids).to match_array(level2_records.map(&:id))
          end
        end

        context 'misspelled association' do
          let(:level0_serializer_class) do
            Class.new(super()) do
              attribute(:category_ids) { lazy_dig(:blog_posts, :misspelled_category).map(&:id) }
            end
          end

          it 'raises ArgumentError' do
            expect { json }
              .to raise_error(ArgumentError, /Undefined lazy 'misspelled_category' relationship for 'Serializer12::BlogPostSerializer' serializer/)
          end
        end
      end

      context '3 level dig' do
        context 'success finding' do
          let(:level0_serializer_class) do
            Class.new(super()) do
              attribute(:category_follower_ids) { lazy_dig(:blog_posts, :category, :category_followers).map(&:id) }
            end
          end

          it 'prevents N+1 queries' do
            expect { json }
              .to make_database_queries(count: 1, matching: 'blog_posts')
              .and make_database_queries(count: 1, matching: 'categories')
              .and make_database_queries(count: 1, matching: 'category_followers')
          end

          it 'digs association properly' do
            json_category_follower_ids = json.dig(:user, :category_follower_ids)
            expect(json_category_follower_ids).to match_array(level3_records.map(&:id))
          end
        end

        context 'misspelled association' do
          let(:level0_serializer_class) do
            Class.new(super()) do
              attribute(:category_follower_ids) { lazy_dig(:blog_posts, :category, :misspelled_category_followers).map(&:id) }
            end
          end

          it 'raises ArgumentError' do
            expect { json }
              .to raise_error(ArgumentError, /Undefined lazy 'misspelled_category_followers' relationship for 'Serializer12::CategorySerializer' serializer/)
          end
        end
      end
    end

    context 'singular association' do
      let(:level0_serializer_class) do
        module Serializer13
          class CategorySerializer < BaseTestSerializer
            lazy_has_many :category_followers
          end

          class BlogPostSerializer < BaseTestSerializer
            lazy_belongs_to :category, serializer: CategorySerializer

            attribute(:lazy_category_id) { lazy_dig(:category).id }
            attribute(:lazy_category_follower_ids) { lazy_dig(:category, :category_followers).map(&:id) }
          end

          class UserSerializer < BaseTestSerializer
            lazy_has_many :blog_posts, serializer: BlogPostSerializer
          end
        end

        Serializer13::UserSerializer
      end

      let(:includes) { ["blog_posts"] }
      let(:blog_post) { level1_records.first }
      let(:json_blog_post) do
        json
          .dig(:user, :blog_posts)
          .detect { |json_blog_post| json_blog_post[:id] == blog_post.id }
      end

      it 'prevents N+1 queries' do
        expect { json }
          .to make_database_queries(count: 1, matching: 'blog_posts')
          .and make_database_queries(count: 1, matching: 'categories')
          .and make_database_queries(count: 1, matching: 'category_followers')
      end

      it 'digs singular object for singular association' do
        json_category_id = json_blog_post[:lazy_category_id]
        expect(json_category_id).to eq(blog_post.category_id)
      end

      it 'digs collection of objects for nested collection association' do
        json_lazy_category_follower_ids = json_blog_post[:lazy_category_follower_ids]
        category_followers = level3_records.select { |cf| cf.category_id == blog_post.category_id }

        expect(json_lazy_category_follower_ids).to match_array(category_followers.map(&:id))
      end
    end
  end

  describe 'include_data AMS setting' do
    shared_examples 'lazy loader when custom finder is specified' do
      let(:adapter_class) { json_api_adapter_class }
      let(:includes) { ['blog_posts'] }
      let(:blog_post_data) { json.dig(:data, :relationships, :blog_posts, :data) }

      it 'loads the association' do
        expect { json }
          .to make_database_queries(count: 1, matching: 'blog_posts')

        expect(blog_post_data).to be_present
      end
    end

    context 'proc-like custom finder' do
      let(:level0_serializer_class) do
        module Serializer14
          class User1Serializer < BaseTestSerializer
            lazy_has_many :blog_posts do |serializer|
              -> { serializer.lazy_blog_posts }
            end
          end
        end

        Serializer14::User1Serializer
      end

      include_examples 'lazy loader when custom finder is specified'
    end

    context 'non-proc custom finder' do
      let(:level0_serializer_class) do
        module Serializer14
          class User2Serializer < BaseTestSerializer
            lazy_has_many :blog_posts do |serializer|
              serializer.lazy_blog_posts
            end
          end
        end

        Serializer14::User2Serializer
      end

      include_examples 'lazy loader when custom finder is specified'
    end

    next unless AMS_VERSION >= Gem::Version.new("0.10.3")

    shared_examples 'lazy loader when include_data option is set' do
      let(:adapter_class) { json_api_adapter_class }
      let(:includes) { ['blog_posts'] }
      let(:category_data) { json.dig(:included, 0, :relationships, :category, :data) }

      it 'does not fire unnecessary SQL query' do
        expect { json }
          .to make_database_queries(count: 1, matching: 'blog_posts')
          .and make_database_queries(count: 0, matching: 'categories')

        expect(category_data).to be_nil
      end

      context 'when sideloaded' do
        let(:includes) { ['blog_posts.category'] }

        it 'fires single SQL query' do
          expect { json }
            .to make_database_queries(count: 1, matching: 'blog_posts')
            .and make_database_queries(count: 1, matching: 'categories')

          expect(category_data).to be_present
        end
      end
    end

    context 'include_data disabled globally' do
      let(:level0_serializer_class) do
        module Serializer15
          class BlogPost1Serializer < BaseTestSerializer
            lazy_belongs_to :category
          end

          class User1Serializer < BaseTestSerializer
            lazy_has_many :blog_posts, serializer: BlogPost1Serializer
          end
        end

        Serializer15::User1Serializer
      end

      around do |example|
        backup = ActiveModel::Serializer.config.include_data_default
        ActiveModel::Serializer.config.include_data_default = :if_sideloaded

        example.run

        ActiveModel::Serializer.config.include_data_default = backup
      end

      include_examples 'lazy loader when include_data option is set'
    end

    context 'include_data disabled locally with custom finder' do
      let(:level0_serializer_class) do
        module Serializer15
          class BlogPost2Serializer < BaseTestSerializer
            lazy_belongs_to :category do |serializer|
              include_data :if_sideloaded
              -> { serializer.lazy_category }
            end
          end

          class User2Serializer < BaseTestSerializer
            lazy_has_many :blog_posts, serializer: BlogPost2Serializer
          end
        end

        Serializer15::User2Serializer
      end

      include_examples 'lazy loader when include_data option is set'
    end

    context 'include_data disabled locally without custom finder' do
      let(:level0_serializer_class) do
        module Serializer15
          class BlogPost3Serializer < BaseTestSerializer
            lazy_belongs_to :category do
              include_data :if_sideloaded
            end
          end

          class User3Serializer < BaseTestSerializer
            lazy_has_many :blog_posts, serializer: BlogPost3Serializer
          end
        end

        Serializer15::User3Serializer
      end

      include_examples 'lazy loader when include_data option is set'
    end
  end

  describe "using serialization scope" do
    class BlogPostsLoader < AmsLazyRelationships::Loaders::Base
      def load_data(records, loader, scope)
        data = []

        records.each do |r|
          d = r.blog_posts
          d = d.where(title: scope[:title]) if scope

          loader.call(r, d)
          data << d
        end

        data.flatten.compact.uniq
      end

      def batch_key(_)
        "Key"
      end
    end

    let(:level0_serializer_class) do
      class Level1Serializer11 < BaseTestSerializer
      end

      class Level0Serializer11 < BaseTestSerializer
        has_many :level1, serializer: Level1Serializer11 do |s|
          s.lazy_level1
        end
        lazy_relationship :level1, loader: BlogPostsLoader.new
      end

      Level0Serializer11
    end
    let(:includes) { ["level1"] }

    before do
      level1_records[0].update!(title: "BP1")
    end

    context "when scope is present" do
      let(:serializer) { level0_serializer_class.new(level0_record, scope: { title: "BP1" }) }

      it "filters the data based on scope" do
        expect(json.dig(:user, :level1).length).to eq(1)
        expect(json.dig(:user, :level1, 0, :id)).to eq(level1_records[0].id)
      end
    end

    context "when scope is blank" do
      it "doesn't filter the data based on scope" do
        expect(json.dig(:user, :level1).length).to eq(3)
      end
    end

    context "when using deprecated loaders" do
      let(:serializer) { level0_serializer_class.new(level0_record, scope: { title: "BP1" }) }

      class DeprecatedBlogPostsLoader < BlogPostsLoader
        def load(records, &block)
          super(records, nil, &block)
        end
      end

      let(:level0_serializer_class) do
        class Level1Serializer12 < BaseTestSerializer
        end

        class Level0Serializer12 < BaseTestSerializer
          has_many :level1, serializer: Level1Serializer12 do |s|
            s.lazy_level1
          end
          lazy_relationship :level1, loader: DeprecatedBlogPostsLoader.new
        end

        Level0Serializer12
      end


      it "works correctly" do
        expect(json.dig(:user, :level1).length).to eq(3)
      end
    end
  end
end
