# frozen_string_literal: true

module AmsLazyRelationships
  module Loaders
    # Batch loads ActiveRecord records belonging to given record by foreign key
    class SimpleHasMany
      # @param association_class_name [String] Name of the ActiveRecord class
      #   e.g. in case when loading all company's accounts it'd be "Account"
      # @param foreign_key [Symbol] association's foreign key.
      #   e.g. in case when loading all company's accounts it'd be :company_id
      def initialize(association_class_name, foreign_key:)
        @association_class_name = association_class_name
        @foreign_key = foreign_key.to_sym
      end

      attr_reader :association_class_name, :foreign_key

      # @param record [Object] an object for which we're loading the has many data
      def load(record, &block)
        key = "#{record.class}/#{association_class_name}"
        BatchLoader.for(record).batch(key: key) do |records, loader|
          data = load_data(records)

          block&.call(data)

          resolve(records, data, loader)
        end
      end

      private

      def load_data(records)
        # Some records use UUID class as id - it's safer to cast them to strings
        record_ids = records.map { |r| r.id.to_s }
        association_class_name.constantize.where(
          foreign_key => record_ids
        ).tap do |data|
          # TODO: Fix me
          # log :info, "record_ids:#{record_ids.join(', ')}", \
          #     "[loaded_ids:#{data.map(&:id).join(', ')}]"
        end
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
