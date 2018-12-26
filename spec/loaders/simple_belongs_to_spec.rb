# frozen_string_literal: true

require "spec_helper"

RSpec.describe AmsLazyRelationships::Loaders::SimpleBelongsTo do
  extend WithArModels

  with_ar_models

  describe "load" do
    let(:blog_post) { BlogPost.create! }
    let!(:record) { Comment.create!(blog_post_id: blog_post.id) }
    let(:loader) { described_class.new("BlogPost") }

    context "when the foreign_key is nil" do
      before do
        record.update_attribute(:blog_post_id, nil)
      end

      it "does not call DB" do
        expect { loader.load(record).itself }.not_to make_database_queries
      end

      it "returns nil" do
        expect(loader.load(record)).to eq(nil)
      end

      it "yields empty array" do
        yielded_data = nil

        promise = loader.load(record) do |data|
          yielded_data = data
        end

        promise.itself

        expect(yielded_data).to eq([])
      end
    end

    context "when the parent record is empty" do
      before do
        BlogPost.delete_all
      end

      it "calls DB" do
        expect { loader.load(record).itself }.
          to make_database_queries(count: 1)
      end

      it "returns nil" do
        expect(loader.load(record)).to eq(nil)
      end

      it "yields empty array" do
        yielded_data = nil

        promise = loader.load(record) do |data|
          yielded_data = data
        end

        promise.itself

        expect(yielded_data).to eq([])
      end
    end

    context "when the relationship is present" do
      it "calls DB" do
        expect { loader.load(record).itself }.
          to make_database_queries(count: 1)
      end

      it "returns the record" do
        expect(loader.load(record)).to eq(blog_post)
      end

      it "yields the loaded data" do
        yielded_data = nil

        promise = loader.load(record) do |data|
          yielded_data = data
        end

        promise.id

        expect(yielded_data).to eq([blog_post])
      end

      context "when using foreign_key option" do
        let(:loader) do
          described_class.new("BlogPost", foreign_key: :blog_post_id)
        end

        it "works" do
          expect(loader.load(record)).to eq(blog_post)
        end
      end
    end

    describe "batch loading" do
      let(:blog_post2) { BlogPost.create! }
      let!(:record2) { Comment.create!(blog_post_id: blog_post2.id) }
      let(:blog_post3) { BlogPost.create! }
      let!(:record3) { Comment.create!(blog_post_id: blog_post3.id) }

      it "calls the db only once and returns correct results" do
        expect do
          c1 = loader.load(record)
          c2 = loader.load(record2)
          c3 = loader.load(record3)

          expect(c1).to eq(blog_post)
          expect(c2).to eq(blog_post2)
          expect(c3).to eq(blog_post3)
        end.to make_database_queries(count: 1)
      end

      it "yields the loaded data" do
        yielded_data = nil
        executions = 0

        block = lambda do |data|
          executions += 1
          yielded_data = data
        end

        [loader.load(record, &block), loader.load(record2, &block)].map(&:id)

        expect(yielded_data).to match_array([blog_post, blog_post2])
        expect(executions).to eq(1)
      end
    end
  end
end
