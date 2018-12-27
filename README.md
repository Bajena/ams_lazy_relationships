[![Build Status](https://travis-ci.org/Bajena/ams_lazy_relationships.svg?branch=master)](https://travis-ci.org/Bajena/ams_lazy_relationships)
[![Maintainability](https://api.codeclimate.com/v1/badges/c21b988e09db63396309/maintainability)](https://codeclimate.com/github/Bajena/ams_lazy_relationships/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/c21b988e09db63396309/test_coverage)](https://codeclimate.com/github/Bajena/ams_lazy_relationships/test_coverage)

# AmsLazyRelationships

Eliminates N+1 queries problem in Active Model Serializers gem thanks to batch loading provided by a great [BatchLoader gem](https://github.com/exAspArk/batch-loader).

The gem provides a module which defines a set of methods useful for eliminating N+1 query problem
during the serialization. Serializers will first prepare a tree of "promises"
for every nested lazy relationship. The relationship promises will be
evaluated only when they're requested.
E.g. when including `blog_posts.user`: instead of loading a user for each blog post separately it'll gather the blog posts and load all their users at once when including the users in the response.

Important: Currently only JSON API adapter has been tested in the wild if you're using a standard JSON adapter let me know :)

## Installation

Add this line to your application's Gemfile:

```ruby
gem "ams_lazy_relationships", git: "git@github.com:Bajena/ams_lazy_relationships.git", branch: :master
```

And then execute:

    $ bundle

## Installation

Include `AmsLazyRelationships::Core` module in your base serializer

```ruby
class BaseSerializer < ActiveModel::Serializer
  include AmsLazyRelationships::Core
end
```

To clear the batch loader's cache between HTTP requests add a following middleware:
`use BatchLoader::Middleware`

For more info about the middleware check out BatchLoader gem docs: https://github.com/exAspArk/batch-loader#caching

### Usage
Adding the `AmsLazyRelationships::Core` module lets you define lazy relationships in your serializers:
```ruby

class UserSerializer < BaseSerializer
  # Short version - preloads a specified ActiveRecord relationships by default
  lazy_has_many :blog_posts
  
  # Works same as the previous one, but the loader option is specified explicitly
  lazy_has_many :blog_posts,
                serializer: BlogPostSerializer,
                loader: AmsLazyRelationships::Loaders::Association.new("User", :blog_posts)
  
  # The previous one is a shorthand for the following lines:
  lazy_relationship :blog_posts, loader: AmsLazyRelationships::Loaders::Association.new("User", :blog_posts)
  has_many :blog_posts, serializer: BlogPostSerializer do
    lazy_blog_posts
  end
                
   
  lazy_has_one :poro_model, loader: AmsLazyRelationships::Loaders::Direct.new(:poro_model) { |object| PoroModel.new(object) }
  
  lazy_belongs_to :account, loader: AmsLazyRelationships::Loaders::SimpleBelongsTo.new("Account")
  
  lazy_has_many :comment, loader: AmsLazyRelationships::Loaders::SimpleHasMany.new("Comment", foreign_key: :user_id)

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

If you're missing a loader you can create an issue or create your own loader taking the existing ones as an example. 

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Bajena/ams_lazy_relationships.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
