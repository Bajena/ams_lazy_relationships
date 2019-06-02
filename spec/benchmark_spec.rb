# frozen_string_literal: true

require "spec_helper"
require "active_model_serializers"
require "benchmark"
require "benchmark/memory"

RSpec.describe AmsLazyRelationships::Core do
  extend WithArModels

  with_ar_models

  class NonLazyUserSerializer < ActiveModel::Serializer
  end

  class NonLazyCommentSerializer < ActiveModel::Serializer
    belongs_to :user, serializer: NonLazyUserSerializer
  end

  class NonLazyBlogPostSerializer < ActiveModel::Serializer
    has_many :comments, serializer: NonLazyCommentSerializer
  end

  class BaseProfSerializer < ActiveModel::Serializer
    include AmsLazyRelationships::Core
  end

  class UserSerializer < BaseProfSerializer
  end

  class CommentSerializer < BaseProfSerializer
    lazy_belongs_to :user, serializer: UserSerializer
  end

  class BlogPostSerializer < BaseProfSerializer
    lazy_has_many :comments, serializer: CommentSerializer
  end

  def serialize(serializer)
    ActiveModelSerializers::SerializableResource.new(
      BlogPost.where(id: blog_posts.map(&:id)),
      each_serializer: serializer,
      adapter: :json_api,
      include: includes
    ).as_json.tap do
      BatchLoader::Executor.clear_current
    end
  end

  let(:includes) do
    ["comments.user"]
  end

  attr_reader :blog_posts

  def create_post(comment_count)
    BlogPost.create!.tap do |bp|
      create_comments(bp, comment_count)
    end
  end

  def create_comments(post, comment_count)
    (1..comment_count).map do
      Comment.create!(blog_post_id: post.id, user_id: User.create!.id)
    end
  end

  before do
    ActiveModelSerializers.logger = Logger.new(nil)
  end

  def benchmark(post_count, comment_count)
    @blog_posts = (1..post_count).map { create_post(comment_count) }
    n = 10

    puts "Experiment (posts: #{post_count}, comments per post: #{comment_count})"
    puts "Time:"

    Benchmark.benchmark("", 25) do |benchmark|
      benchmark.report("With lazy relationships:") do
        n.times { serialize(BlogPostSerializer) }
      end

      benchmark.report("Vanilla AMS:") do
        n.times { serialize(NonLazyBlogPostSerializer) }
      end
    end

    puts "Memory:"

    Benchmark.memory do |bmem|
      bmem.report("With lazy relationships:") do
        n.times { serialize(BlogPostSerializer) }
      end

      bmem.report("Vanilla AMS:") do
        n.times { serialize(NonLazyBlogPostSerializer) }
      end
    end
  end

  xit "Performance benchmark" do
    benchmark(1, 1)
    benchmark(1, 10)
    benchmark(10, 1)
    benchmark(10, 10)
    benchmark(100, 10)
    benchmark(10, 100)
    benchmark(100, 100)
  end
end

# Experiment (posts: 1, comments per post: 1)
# Time:
# With lazy relationships:    0.050000   0.010000   0.060000 (  0.065191)
# Vanilla AMS:                0.030000   0.000000   0.030000 (  0.029424)
# Memory:
# Calculating -------------------------------------
# With lazy relationships:
#                          1.130M memsize (     0.000  retained)
#                         13.956k objects (     0.000  retained)
#                         50.000  strings (     0.000  retained)
#         Vanilla AMS:   887.690k memsize (     0.000  retained)
#                         11.816k objects (     0.000  retained)
#                         50.000  strings (     0.000  retained)
# Experiment (posts: 1, comments per post: 10)
# Time:
# With lazy relationships:    0.110000   0.000000   0.110000 (  0.105953)
# Vanilla AMS:                0.100000   0.000000   0.100000 (  0.105560)
# Memory:
# Calculating -------------------------------------
# With lazy relationships:
#                          4.962M memsize (     0.000  retained)
#                         55.416k objects (     0.000  retained)
#                         50.000  strings (     0.000  retained)
#         Vanilla AMS:     4.340M memsize (     0.000  retained)
#                         55.016k objects (     0.000  retained)
#                         50.000  strings (     0.000  retained)
# Experiment (posts: 10, comments per post: 1)
# Time:
# With lazy relationships:    0.170000   0.000000   0.170000 (  0.168016)
# Vanilla AMS:                0.170000   0.010000   0.180000 (  0.175634)
# Memory:
# Calculating -------------------------------------
# With lazy relationships:
#                          8.154M memsize (     0.000  retained)
#                         93.596k objects (     0.000  retained)
#                         50.000  strings (     0.000  retained)
#         Vanilla AMS:     7.697M memsize (     0.000  retained)
#                        102.466k objects (     0.000  retained)
#                         50.000  strings (     0.000  retained)
# Experiment (posts: 10, comments per post: 10)
# Time:
# With lazy relationships:    0.860000   0.010000   0.870000 (  0.870297)
# Vanilla AMS:                1.050000   0.000000   1.050000 (  1.059801)
# Memory:
# Calculating -------------------------------------
# With lazy relationships:
#                         46.283M memsize (     0.000  retained)
#                        506.696k objects (     0.000  retained)
#                         50.000  strings (     0.000  retained)
#         Vanilla AMS:    42.738M memsize (     0.000  retained)
#                        545.266k objects (     0.000  retained)
#                         50.000  strings (     0.000  retained)
# Experiment (posts: 100, comments per post: 10)
# Time:
# With lazy relationships:   10.210000   0.060000  10.270000 ( 10.298336)
# Vanilla AMS:               12.270000   0.050000  12.320000 ( 12.358776)
# Memory:
# Calculating -------------------------------------
# With lazy relationships:
#                        459.252M memsize (    40.000  retained)
#                          5.016M objects (     1.000  retained)
#                         50.000  strings (     0.000  retained)
#         Vanilla AMS:   425.823M memsize (    40.000  retained)
#                          5.432M objects (     1.000  retained)
#                         50.000  strings (     0.000  retained)
# Experiment (posts: 10, comments per post: 100)
# Time:
# With lazy relationships:    9.820000   0.260000  10.080000 ( 10.080571)
# Vanilla AMS:                9.260000   0.160000   9.420000 (  9.422104)
# Memory:
# Calculating -------------------------------------
# With lazy relationships:
#                        427.364M memsize (     0.000  retained)
#                          4.638M objects (     0.000  retained)
#                         50.000  strings (     0.000  retained)
#         Vanilla AMS:   392.713M memsize (     0.000  retained)
#                          4.973M objects (     0.000  retained)
#                         50.000  strings (     0.000  retained)
# Experiment (posts: 100, comments per post: 100)
# Time:
# With lazy relationships:   86.900000   0.960000  87.860000 ( 87.898241)
# Vanilla AMS:               96.620000   0.100000  96.720000 ( 96.769373)
