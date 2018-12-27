module WithArModels
  def with_ar_models
    with_model :User do
      table do |t|
        t.string :name
        t.timestamps
      end

      model do
        has_many :comments
        has_many :blog_posts
      end
    end

    with_model :Category do
      table do |t|
        t.timestamps null: false
      end
    end

    with_model :CategoryFollower do
      table do |t|
        t.integer :category_id

        t.timestamps null: false
      end
    end

    with_model :BlogPost do
      table do |t|
        t.string :title
        t.belongs_to :user
        t.integer :category_id
        t.timestamps null: false
      end

      model do
        belongs_to :user
        belongs_to :category
        has_many :comments
        has_many :comments_with_options,
                 -> { where(body: "x") },
                 class_name: "Comment"
      end
    end

    with_model :Comment do
      table do |t|
        t.string :body
        t.belongs_to :blog_post
        t.belongs_to :user
        t.timestamps
      end

      model do
        belongs_to :user
        belongs_to :blog_post
        belongs_to :blog_post_with_options,
                   -> { where(title: "x") },
                   class_name: "BlogPost",
                   foreign_key: "blog_post_id"
      end
    end
  end
end
