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
      # @param serializer_instance [Object] Serializer instance for an object for which we're loading the data
      # @param block [Proc] a block to execute when data is evaluated
      #  Loaded data is yielded as a block argument.
      def load(serializer_instance, load_for, &block)
        record = if load_for.present?
                   serializer_instance.object.public_send(load_for)
                 else
                   serializer_instance.object
                 end

        BatchLoader.for(record).batch(key: cache_key(record)) do |records, loader|
          data = load_data(records)

          block&.call(data)

          resolve(records, data, loader)
        end
      end

      private

      attr_reader :association_class_name, :foreign_key

      def load_data(records)
        data_ids = records.map(&foreign_key).compact.uniq
        data = if data_ids.present?
                 association_class_name.constantize.where(id: data_ids)
               else
                 []
               end

        data
      end

      def resolve(records, data, loader)
        data = data.index_by { |d| d.id.to_s }
        records.each do |r|
          fk_value = r.public_send(foreign_key).to_s
          loaded_item = data[fk_value]
          loader.call(r, loaded_item)
        end
      end

      def cache_key(record)
        "#{record.class}/#{association_class_name}"
      end
    end
  end
end
