[![Build Status](https://travis-ci.com/Bajena/ams_lazy_relationships.svg?branch=master)](https://travis-ci.com/Bajena/ams_lazy_relationships)
[![Maintainability](https://api.codeclimate.com/v1/badges/c21b988e09db63396309/maintainability)](https://codeclimate.com/github/Bajena/ams_lazy_relationships/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/c21b988e09db63396309/test_coverage)](https://codeclimate.com/github/Bajena/ams_lazy_relationships/test_coverage)

# AmsLazyRelationships

#### What does the gem do?
Eliminates N+1 queries problem in [Active Model Serializers gem](https://github.com/rails-api/active_model_serializers) thanks to batch loading provided by a great [BatchLoader gem](https://github.com/exAspArk/batch-loader).

The gem provides a module which defines a set of methods useful for eliminating N+1 query problem
during the serialization. Serializers will first prepare a tree of "promises"
for every nested lazy relationship. The relationship promises will be
evaluated only when they're requested.
E.g. when including `blog_posts.user`: instead of loading a user for each blog post separately it'll gather the blog posts and load all their users at once when including the users in the response.

#### How is it better than Rails' includes/joins methods?
In many cases it's fine to use [`includes`](https://apidock.com/rails/ActiveRecord/QueryMethods/includes) method provided by Rails. 
There are a few problems with `includes` approach though:
- It loads all the records provided in the arguments hash. Often you may not need all the nested records to serialize the data you want. `AmsLazyRelationships` will load only the data you need thanks to lazy evaluation.
- When the app gets bigger and bigger you'd need to update all the `includes` statements across your app to prevent the N+1 queries problem which quickly becomes impossible.
- It lets you remove N+1s even when not all relationships are ActiveRecord models (e.g. some records are stored in a MySQL DB and other models are stored in Cassandra)

## Installation

1. Add this line to your application's Gemfile:

```ruby
gem "ams_lazy_relationships"
```

2. Execute:
```
$ bundle
```

3. Include `AmsLazyRelationships::Core` module in your base serializer

```ruby
class BaseSerializer < ActiveModel::Serializer
  include AmsLazyRelationships::Core
end
```

4. **Important:** 
This gem uses `BatchLoader` heavily. I highly recommend to clear the batch loader's cache between HTTP requests.
To do so add a following middleware:
`config.middleware.use BatchLoader::Middleware` to your app's `application.rb`.

For more info about the middleware check out BatchLoader gem docs: https://github.com/exAspArk/batch-loader#caching

## Usage
Adding the `AmsLazyRelationships::Core` module lets you define lazy relationships in your serializers:
```ruby

class UserSerializer < BaseSerializer
  # Short version - preloads a specified ActiveRecord relationship by default
  lazy_has_many :blog_posts
  
  # Works same as the previous one, but the loader option is specified explicitly
  lazy_has_many :blog_posts,
                serializer: BlogPostSerializer,
                loader: AmsLazyRelationships::Loaders::Association.new("User", :blog_posts)
  
  # The previous one is a shorthand for the following lines:
  lazy_relationship :blog_posts, loader: AmsLazyRelationships::Loaders::Association.new("User", :blog_posts)
  has_many :blog_posts, serializer: BlogPostSerializer do |serializer|
    serializer.lazy_blog_posts
  end
   
  lazy_has_one :poro_model, loader: AmsLazyRelationships::Loaders::Direct.new(:poro_model) { |object| PoroModel.new(object) }
  
  lazy_belongs_to :account, loader: AmsLazyRelationships::Loaders::SimpleBelongsTo.new("Account")
  
  lazy_has_many :comment, loader: AmsLazyRelationships::Loaders::SimpleHasMany.new("Comment", foreign_key: :user_id)
end
```

As you may have already noticed the gem makes use of various loader classes. 

I've implemented the following ones for you:
- `AmsLazyRelationships::Loaders::Association` - Batch loads a ActiveRecord association (has_one/has_many/has_many-through/belongs_to). This is a deafult loader in case you don't specify a `loader` option in your serializer's lazy relationship.
E.g. in order to lazy load user's blog posts use a following loader: `AmsLazyRelationships::Loaders::Association.new("User", :blog_posts)`.

- `AmsLazyRelationships::Loaders::SimpleBelongsTo` - Batch loads ActiveRecord models using a foreign key method called on a serialized object. E.g. `AmsLazyRelationships::Loaders::SimpleBelongsTo.new("Account")` called on users will gather their `account_id`s and fire one query to get all accounts at once instead of loading an account per user separately. 
This loader can be useful e.g. when the serialized object is not an ActiveRecord model.

- `AmsLazyRelationships::Loaders::SimpleHasMany` - Batch loads ActiveRecord records belonging to given record by foreign key. E.g. `AmsLazyRelationships::Loaders::SimpleHasMany.new("BlogPosts", foreign_key: :user_id)` called on users will  and fire one query to gather all blog posts for the users at once instead of loading an the blog posts per user separately.
This loader can be useful e.g. when the serialized object is not an ActiveRecord model.

- `AmsLazyRelationships::Loaders::Direct` - Lazy loads data in a "dumb" way - just executes the provided block when needed. Useful e.g. when the relationship is just a PORO which then in its own serializer needs to lazy load some relationships.
You can use it like this: `AmsLazyRelationships::Loaders::Direct.new(:poro_model) { |object| PoroModel.new(object)`.

The abovementioned loaders are mostly useful when using ActiveRecord, but there should be no problem building a new loader for different frameworks.
If you're missing a loader you can create an issue or create your own loader taking the existing ones as an example. 

### More examples
Here are a few use cases for the lazy relationships. Hopefully they'll let you understand a bit more how the gem works.

#### Example 1: Basic ActiveRecord relationships
If the relationships in your serializers are plain old ActiveRecord relationships you're lucky, because ams_lazy_relationships by default assumes that the relationship is an ActiveRecord relationship, so you can use the simplest syntax.
Imagine you have an endpoint that renders a list of blog posts and includes their comments.
The N+1 prone way of defining the serializer would be:
```ruby
class BlogPostSerializer < BaseSerializer
  has_many :comments
end
```

To prevent loading comments using a separate DB query for each post just change it to:
```ruby
class BlogPostSerializer < BaseSerializer
  lazy_has_many :comments
end
```

#### Example 2: Modifying the relationship before rendering
Sometimes it may happen that you need to process the relationship before rendering, e.g. decorate the records. In this case the gem provides a special method (in our case `lazy_comments`) for each defined relationship. Check out the example - we'll decorate every comment before serializing:

```ruby
class BlogPostSerializer < BaseSerializer
  lazy_has_many :comments do |serializer|
    serializer.lazy_comments.map(&:decorate)
   end
end
```

#### Example 3: Introducing loader classes
Under the hood ams_lazy_relationships uses special loader classes to batch load the relationships. By default the gem uses serializer class names and relationship names to instantiate correct loaders, but it may happen that e.g. your serializer's class name doesn't match the model name (e.g. your model's name is `BlogPost` but the serializer's name is `PostSerializer`).

In this case you can define the lazy relationship by passing a correct loader param:
```ruby
class PostSerializer < BaseSerializer
  lazy_has_many :comments, serializer: CommentSerializer,
    loader: AmsLazyRelationships::Loaders::Association.new(
              "BlogPost", :comments
            )
end
```

#### Example 4: Non ActiveRecord -> ActiveRecord relationships
This one is interesting. It may happen that the root record is not an ActiveRecord model (e.g. a Cequel model), however its relationship is an AR model.
Imagine that `BlogPost` is not an AR model and `Comment` is a standard AR model. The lazy relationship would look like this:
```ruby
class BlogPostSerializer < BaseSerializer
  lazy_has_many :comments, 
    loader: AmsLazyRelationships::Loaders::SimpleHasMany.new(
      "Comment", foreign_key: :blog_post_id
    )
end
```

#### Example 5: Use lazy relationship without rendering it
Sometimes you may just want to make use of lazy relationship without rendering the whole nested record. 
For example imagine that your `BlogPost` serializer is supposed to render `author_name` attribute. You can define the lazy relationship and just use it in other attribute evaluator:

```ruby
class BlogPostSerializer < BaseSerializer
  lazy_relationship :author
  
  attribute :author_name do
    lazy_author.name
  end
end
```

#### Example 6: Lazy dig through relationships
In additional to previous example you may want to make use of nested lazy relationship without rendering of any nested record.
There is an `lazy_dig` method to be used for that:

```ruby
class AuthorSerializer < BaseSerializer
  lazy_relationship :address
end

class BlogPostSerializer < BaseSerializer
  lazy_relationship :author

  attribute :author_address do
    lazy_dig(:author, :address)&.full_address
  end
end
```

## Performance comparison with vanilla AMS

In general the bigger and more complex your serialized records hierarchy is and the more latency you have in your DB the more you'll benefit from using this gem. 
Example results for average size records tree (10 blog posts -> 10 comments each -> 1 user per comment, performed on local in-memory SQLite DB) are:

### Time:

```bash
# With lazy relationships:    0.860000   0.010000   0.870000 (  0.870297)
# Vanilla AMS:                1.050000   0.000000   1.050000 (  1.059801)
```

This means your serializers should get **~13%** speed boost by introducing lazy relationships.

### Memory:

```bash
# With lazy relationships:
#                         46.283M memsize (     0.000  retained)
#                        506.696k objects (     0.000  retained)
#                         50.000  strings (     0.000  retained)
# Vanilla AMS:            42.738M memsize (     0.000  retained)
#                        545.266k objects (     0.000  retained)
#                         50.000  strings (     0.000  retained)
```

This means that serialization may consume **~5%** more memory.

Detailed benchmark script & results can be found [here](/spec/benchmark_spec.rb).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Bajena/ams_lazy_relationships.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
