# frozen_string_literal: true

module AmsLazyRelationships
  module Loaders
    # Batch loads ActiveRecord records belonging to given record by foreign key.
    # Useful when the relationship is not a standard ActiveRecord relationship.
    class SimpleHasMany
      # @param association_class_name [String] Name of the ActiveRecord class
      #   e.g. in case when loading blog_post.comments it'd be "Comment"
      # @param foreign_key [Symbol] association's foreign key.
      #   e.g. in case when loading blog_post.comments it'd be :blog_post_id
      def initialize(association_class_name, foreign_key:)
        @association_class_name = association_class_name
        @foreign_key = foreign_key.to_sym
      end

      # Lazy loads and yields the data when evaluating
      # @param record [Object] an object for which we're loading the has many data
      # @param block [Proc] a block to execute when data is evaluated.
      #  Loaded data is yielded as a block argument.
      def load(record, &block)
        key = "#{record.class}/#{association_class_name}"
        BatchLoader.for(record).batch(key: key, replace_methods: false) do |records, loader|
          data = load_data(records)

          block&.call(data)

          resolve(records, data, loader)
        end
      end

      private

      attr_reader :association_class_name, :foreign_key

      def load_data(records)
        # Some records use UUID class as id - it's safer to cast them to strings
        record_ids = records.map { |r| r.id.to_s }
        association_class_name.constantize.where(
          foreign_key => record_ids
        )
      end

      def resolve(records, data, loader)
        data = data.group_by { |d| d.public_send(foreign_key).to_s }

        records.each do |r|
          loader.call(r, data[r.id.to_s] || [])
        end
      end
    end
  end
end
