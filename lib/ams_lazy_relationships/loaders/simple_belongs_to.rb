# frozen_string_literal: true

module AmsLazyRelationships
  module Loaders
    # Batch loads parent ActiveRecord records for given record by foreign key
    class SimpleBelongsTo
      # @param association_class_name [String] The name of AR class being the parent
      #   record of the records being loaded. E.g. When loading account.company
      #   it'd be "Company".
      # @param foreign_key [Symbol/String] Name of the foreign key column
      #   E.g. When loading account.company it'd be "company_id"
      def initialize(
        association_class_name,
        foreign_key: "#{association_class_name.underscore}_id"
      )
        @association_class_name = association_class_name
        @foreign_key = foreign_key.to_sym
      end

      attr_reader :association_class_name, :foreign_key

      # Lazy loads and yields the data when evaluating
      def load(record, &block)
        BatchLoader.for(record).batch(key: cache_key(record)) do |records, loader|
          data = load_data(records)

          block&.call(data)

          resolve(records, data, loader)
        end
      end

      private

      def load_data(records)
        data_ids = records.map(&foreign_key).compact.uniq
        data = if data_ids.present?
                 association_class_name.constantize.where(id: data_ids)
               else
                 []
               end

        log_loaded_data(records, data_ids, data)

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

      # TODO: Fix me
      def log_loaded_data(records, data_ids, data)
        # record_ids = records.map { |r| r.id.to_s }
        # log(
        #   :info, records.first.class, "record_ids:#{record_ids.join(', ')}",
        #   "requested_ids:#{data_ids.join(', ')}",
        #   "[loaded_ids:#{data.map(&:id).join(', ')}]"
        # )
      end
    end
  end
end
