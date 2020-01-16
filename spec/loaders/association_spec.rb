# frozen_string_literal: true

require "spec_helper"

RSpec.describe AmsLazyRelationships::Loaders::Association do
  extend WithArModels

  with_ar_models

  context "belongs_to associations" do
    let(:blog_post) { BlogPost.create! }
    let!(:record) { Comment.create!(blog_post_id: blog_post.id) }
    let(:loader) { described_class.new("Comment", :blog_post) }

    context "when the relationship was already cached by AR" do
      before do
        record.blog_post
      end

      it "does not call DB" do
        expect { loader.load(record).itself }.not_to make_database_queries
      end

      it "returns the cached relationship" do
        expect(loader.load(record)).to eq(blog_post)
      end

      it "does not return data immediately, but BatchLoader instance instead" do
        x = loader.load(record)
        expect(x.inspect).to include("BatchLoader")
        x = x.itself
        expect(x.inspect).to include("BlogPost")
      end

      it "yields the loaded data but only when it is required" do
        yielded_data = nil

        promise = loader.load(record) do |data|
          yielded_data = data
        end

        # Data should not be yielded yet
        expect(yielded_data).to eq(nil)

        promise.id

        expect(yielded_data).to eq([blog_post])
      end

      context "when one of the records was cached but other not" do
        let(:blog_post2) { BlogPost.create! }
        let!(:record2) { Comment.create!(blog_post_id: blog_post2.id) }

        it "queries only for one record" do
          expect do
            c1 = loader.load(record)
            c2 = loader.load(record2)

            expect(c1).to eq(blog_post)
            expect(c2).to eq(blog_post2)
          end.to make_database_queries(
            count: 1,
            # If blog_post wasn't cached then a query with "id" IN() would be called
            matching: /SELECT.*FROM.*blog_posts.*WHERE.*blog_posts.*\"id\" = /
          )
        end
      end
    end

    context "when the relationship is empty" do
      let(:record) { Comment.create!(blog_post_id: nil) }

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
        expect { loader.load(record).try(&:id) }.
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
    end

    describe "batch loading" do
      let(:reloaded_record) do
        Comment.find(record.id)
      end
      let(:blog_post2) { BlogPost.create! }
      let!(:record2) { Comment.create!(blog_post_id: blog_post2.id) }

      it "calls the db only once and returns correct results" do
        expect do
          c1 = loader.load(reloaded_record)
          c2 = loader.load(record2)

          expect(c1).to eq(blog_post)
          expect(c2).to eq(blog_post2)
        end.to make_database_queries(
          count: 1,
          matching: /SELECT.*FROM.*blog_posts.*WHERE.*blog_posts.*\"id\" IN \(\?, \?\)/
        )
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

    describe "handling relation scopes" do
      let(:blog_post2) { BlogPost.create!(title: "x") }
      let(:record2) { Comment.create!(blog_post_id: blog_post2.id) }
      let(:loader) { described_class.new("Comment", :blog_post_with_options) }

      it "applies the scope" do
        c1 = loader.load(record)
        c2 = loader.load(record2)

        expect(c1).to eq(nil)
        expect(c2).to eq(blog_post2)
      end
    end
  end

  describe "has_many relationships" do
    let!(:record) do
      BlogPost.create!
    end
    let!(:comment) do
      Comment.create!(blog_post_id: record.id)
    end
    let(:loader) { described_class.new("BlogPost", :comments) }

    context "when the relationship was already cached by AR" do
      before do
        record.comments.map(&:id)
      end

      it "does not call DB" do
        expect { loader.load(record).map(&:id) }.
          not_to make_database_queries
      end

      it "returns the cached relationship" do
        expect(loader.load(record)).to eq([comment])
      end
    end

    context "when there are no records" do
      before do
        comment.destroy
      end

      it "returns empty array" do
        expect(loader.load(record)).to eq([])
      end
    end

    context "when the relationship is present" do
      it "calls DB" do
        expect { loader.load(record).map(&:id) }.
          to make_database_queries(count: 1)
      end

      it "returns the records" do
        expect(loader.load(record)).to eq([comment])
      end
    end

    describe "batch loading" do
      let(:record2) { BlogPost.create! }
      let!(:comment2) do
        Comment.create!(blog_post_id: record2.id)
      end

      it "calls the db only once and returns correct results" do
        expect do
          t1 = loader.load(record)
          t2 = loader.load(record2)

          expect(t1).to eq([comment])
          expect(t2).to eq([comment2])
        end.to make_database_queries(count: 1)
      end

      it "yields the loaded data" do
        yielded_data = nil
        executions = 0

        block = lambda do |data|
          executions += 1
          yielded_data = data
        end

        promises = [loader.load(record, &block), loader.load(record2, &block)]
        promises.map(&:itself) # Execute lazy blocks
        expect(yielded_data).to match_array([comment, comment2])
        expect(executions).to eq(1)
      end
    end

    describe "handling relation scopes" do
      let(:loader) { described_class.new("BlogPost", :comments_with_options) }
      let(:record2) { BlogPost.create! }
      let!(:comment2) do
        Comment.create!(blog_post_id: record2.id, body: "x")
      end
      let!(:comment3) do
        Comment.create!(blog_post_id: record2.id, body: "y")
      end

      it "applies the scope" do
        t1 = loader.load(record)
        t2 = loader.load(record2)

        expect(t1).to eq([])
        expect(t2).to eq([comment2])
      end
    end

    context "association populated by accepts_nested_attributes_for" do
      let(:record) { User.create!(blog_posts_attributes: [{title: 'Foo'}]) }
      let(:loader) { described_class.new("User", :blog_posts) }

      it "avoids the duplication of associated records" do
        expect(loader.load(record).size).to eq(1)
      end
    end
  end

  context "when loading multiple lazy associations" do
    let!(:record) { BlogPost.create!(user_id: user.id) }
    let(:user) { User.create! }
    let!(:comment) do
      Comment.create!(blog_post_id: record.id)
    end

    let(:comments_loader) do
      described_class.new("BlogPost", :comments)
    end
    let(:user_loader) do
      described_class.new("BlogPost", :user)
    end

    it "works fine" do
      expect(comments_loader.load(record)).to eq([comment])
      expect(user_loader.load(record)).to eq(user)
    end
  end
end
