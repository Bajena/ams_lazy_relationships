# frozen_string_literal: true

require "ams_lazy_relationships/loaders/base"

module AmsLazyRelationships
  module Loaders
    # Lazy loads data in a "dumb" way - just executes the provided block when needed
    class Direct < Base
      # @param relationship_name [Symbol] used for building cache key. Also if the
      #   `load_block` param is `nil` the loader will just call `relationship_name`
      #   method on the record being processed.
      # @param load_block [Proc] If present the loader will call this block when
      #   evaluating the data.
      def initialize(relationship_name, &load_block)
        @relationship_name = relationship_name
        @load_block = load_block
      end

      private

      attr_reader :relationship_name, :load_block

      def load_data(records, loader, _scope)
        data = []
        records.each do |r|
          value = calculate_value(r)
          data << value
          loader.call(r, value)
        end

        data = data.flatten.compact.uniq
      end

      def batch_key(record)
        "#{record.class}/#{relationship_name}"
      end

      def calculate_value(record)
        return record.public_send(relationship_name) unless load_block

        load_block.call(record)
      end
    end
  end
end
