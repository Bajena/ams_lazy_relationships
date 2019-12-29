# frozen_string_literal: true

require "ams_lazy_relationships/loaders/base"

module AmsLazyRelationships
  module Loaders
    # Batch loads parent ActiveRecord records for given record by foreign key.
    # Useful when the relationship is not a standard ActiveRecord relationship.
    class SimpleBelongsTo < Base
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

      private

      attr_reader :association_class_name, :foreign_key

      def load_data(records, loader, scope)
        data_ids = records.map(&foreign_key).compact.uniq
        data = if data_ids.present?
                 association_class_name.constantize.where(id: data_ids)
               else
                 []
               end

        resolve(records, data, loader)

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

      def batch_key(record)
        "#{record.class}/#{association_class_name}"
      end
    end
  end
end
