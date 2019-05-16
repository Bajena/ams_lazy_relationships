# frozen_string_literal: true

module AmsLazyRelationships
  module Loaders
    # Batch loads parent ActiveRecord records for given record by foreign key.
    # Useful when the relationship is not a standard ActiveRecord relationship.
    class SimpleBelongsTo
      # @param association_class_name [String] The name of AR class being the parent
      #   record of the records being loaded. E.g. When loading comment.blog_post
      #   it'd be "BlogPost".
      # @param foreign_key [Symbol/String] Name of the foreign key column
      #   E.g. When loading comment.blog_post it'd be "blog_post_id
      def initialize(
        association_class_name,
        foreign_key: "#{association_class_name.underscore}_id"
      )
        @association_class_name = association_class_name
        @foreign_key = foreign_key.to_sym
      end

      # Lazy loads and yields the data when evaluating
      # @param record [Object] an object for which we're loading the belongs to data
      # @param block [Proc] a block to execute when data is evaluated
      #  Loaded data is yielded as a block argument.
      def load(record, &block)
        BatchLoader.for(record.public_send(foreign_key).to_s.presence).batch(key: cache_key(record)) do |fks, loader|
          data = load_data(fks)

          block&.call(data)

          resolve(fks, data, loader)
        end
      end

      private

      attr_reader :association_class_name, :foreign_key

      def load_data(fks)
        data_ids = fks.compact.uniq
        data = if data_ids.present?
                 association_class_name.constantize.where(id: data_ids)
               else
                 []
               end

        data
      end

      def resolve(fks, data, loader)
        data = data.index_by { |d| d.id.to_s }
        fks.each do |fk|
          loaded_item = data[fk]
          loader.call(fk, loaded_item)
        end
      end

      def cache_key(record)
        "#{record.class}/#{association_class_name}"
      end
    end
  end
end
