# frozen_string_literal: true

require "ams_lazy_relationships/loaders/base"

module AmsLazyRelationships
  module Loaders
    # Batch loads ActiveRecord records belonging to given record by foreign key.
    # Useful when the relationship is not a standard ActiveRecord relationship.
    class SimpleHasMany < Base
      # @param association_class_name [String] Name of the ActiveRecord class
      #   e.g. in case when loading blog_post.comments it'd be "Comment"
      # @param foreign_key [Symbol] association's foreign key.
      #   e.g. in case when loading blog_post.comments it'd be :blog_post_id
      def initialize(association_class_name, foreign_key:)
        @association_class_name = association_class_name
        @foreign_key = foreign_key.to_sym
      end

      private

      attr_reader :association_class_name, :foreign_key

      def load_data(records, loader)
        # Some records use UUID class as id - it's safer to cast them to strings
        record_ids = records.map { |r| r.id.to_s }
        association_class_name.constantize.where(
          foreign_key => record_ids
        ).tap do |data|
          resolve(records, data, loader)
        end
      end

      def resolve(records, data, loader)
        data = data.group_by { |d| d.public_send(foreign_key).to_s }

        records.each do |r|
          loader.call(r, data[r.id.to_s] || [])
        end
      end

      def batch_key(record)
        "#{record.class}/#{association_class_name}"
      end
    end
  end
end
