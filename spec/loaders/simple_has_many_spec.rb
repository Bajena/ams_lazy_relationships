# frozen_string_literal: true

require "spec_helper"

RSpec.describe AmsLazyRelationships::Loaders::SimpleHasMany do
  extend WithArModels

  with_ar_models

  describe "load" do
    let(:record) { BlogPost.create! }
    let!(:comments) do
      2.times.map do
        Comment.create!(blog_post_id: record.id)
      end
    end
    let(:loader) do
      described_class.new(
        "Comment",
        foreign_key: :blog_post_id
      )
    end

    context "when the relationship is present" do
      it "calls DB" do
        expect { loader.load(record).map(&:itself) }.
          to make_database_queries(count: 1)
      end

      it "returns the record" do
        expect(loader.load(record)).to eq(comments)
      end

      it "yields the data" do
        yielded_data = nil

        promise = loader.load(record) do |data|
          yielded_data = data
        end

        promise.map(&:itself)

        expect(yielded_data).to eq(comments)
      end
    end

    context "when there are no records" do
      before do
        Comment.delete_all
      end

      it "calls DB" do
        expect { loader.load(record).map(&:itself) }.
          to make_database_queries(count: 1)
      end

      it "returns empty array" do
        expect(loader.load(record)).to eq([])
      end

      it "yields an empty array" do
        yielded_data = nil

        promise = loader.load(record) do |data|
          yielded_data = data
        end

        promise.map(&:itself)

        expect(yielded_data).to eq([])
      end
    end

    describe "batch loading" do
      let!(:record2) { BlogPost.create! }
      let!(:record2_comment) do
        Comment.create!(blog_post_id: record2.id)
      end

      it "calls the db only once and returns correct results" do
        expect do
          c1 = loader.load(record)
          c2 = loader.load(record2)

          expect(c1).to eq(comments)
          expect(c2).to eq([record2_comment])
        end.to make_database_queries(count: 1)
      end

      it "yields the loaded data" do
        yielded_data = nil
        executions = 0

        block = lambda do |data|
          executions += 1
          yielded_data = data
        end

        # Gather and lazy evaluate
        [loader.load(record, &block), loader.load(record2, &block)].map(&:itself)

        expect(yielded_data).
          to match_array(comments + [record2_comment])
        expect(executions).to eq(1)
      end
    end

    context "when record has multiple lazy has many" do
      let!(:record) { User.create! }
      let!(:comment) do
        Comment.create!(user_id: record.id)
      end
      let!(:blog_post) { BlogPost.create!(user_id: record.id) }

      let(:comments_loader) do
        described_class.new("Comment", foreign_key: :user_id)
      end
      let(:blog_posts_loader) do
        described_class.new("BlogPost", foreign_key: :user_id)
      end

      it "works fine" do
        expect(comments_loader.load(record)).to eq([comment])
        expect(blog_posts_loader.load(record)).to eq([blog_post])
      end
    end
  end
end
