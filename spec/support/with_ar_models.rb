module WithArModels
  def with_ar_models
    with_model :User do
      table do |t|
        t.timestamps
      end

      # The model block is the ActiveRecord model’s class body.
      model do
        has_many :comments
        has_many :blog_posts
      end
    end

    with_model :BlogPost do
      # The table block (and an options hash) is passed to ActiveRecord migration’s `create_table`.
      table do |t|
        t.string :title
        t.belongs_to :user
        t.timestamps null: false
      end

      # The model block is the ActiveRecord model’s class body.
      model do
        belongs_to :user
        has_many :comments
        has_many :comments_with_options,
                 -> { where(body: "x") },
                 class_name: "Comment"
      end
    end

    # with_model classes can have associations.
    with_model :Comment do
      table do |t|
        t.string :body
        t.belongs_to :blog_post
        t.belongs_to :user
        t.timestamps
      end

      model do
        belongs_to :blog_post
        belongs_to :blog_post_with_options,
                   -> { where(title: "x") },
                   class_name: "BlogPost",
                   foreign_key: "blog_post_id"
      end
    end
  end
end
