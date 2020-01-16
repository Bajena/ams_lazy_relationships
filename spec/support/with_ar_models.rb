module WithArModels
  def with_ar_models
    with_model :User do
      table(id: :uuid) do |t|
        t.string :name
        t.timestamps
      end

      model do
        before_create { self.id = SecureRandom.uuid }
        has_many :comments
        has_many :blog_posts
        accepts_nested_attributes_for :blog_posts
      end
    end

    with_model :Category do
      table(id: :uuid) do |t|
        t.timestamps null: false
      end

      model do
        before_create { self.id = SecureRandom.uuid }
        has_many :category_followers
      end
    end

    with_model :CategoryFollower do
      table(id: :uuid) do |t|
        t.string :category_id

        t.timestamps null: false
      end

      model do
        before_create { self.id = SecureRandom.uuid }
      end
    end

    with_model :BlogPost do
      table(id: :uuid) do |t|
        t.string :title
        t.string :user_id
        t.string :category_id
        t.timestamps null: false
      end

      model do
        before_create { self.id = SecureRandom.uuid }
        belongs_to :user
        belongs_to :category
        has_many :comments
        has_many :comments_with_options,
                 -> { where(body: "x") },
                 class_name: "Comment"
      end
    end

    with_model :Comment do
      table(id: :uuid) do |t|
        t.string :body
        t.string :blog_post_id
        t.string :user_id
        t.timestamps
      end

      model do
        before_create { self.id = SecureRandom.uuid }
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
