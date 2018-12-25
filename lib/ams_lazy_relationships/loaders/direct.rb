# frozen_string_literal: true

module AmsLazyRelationships
  module Loaders
    # Lazy loads data in a "dumb" way - just executes the provided block when needed
    class Direct

      # @param relationship_name [Symbol] used for building cache key. Also if the
      #   `load_block` param is `nil` the loader will just call `relationship_name`
      #   method on the record being processed.
      # @param load_block [Proc] If present the loader will call this block when
      #   evaluating the data.
      def initialize(relationship_name, &load_block)
        @relationship_name = relationship_name
        @load_block = load_block
      end

      # Lazy loads and yields the data when evaluating
      def load(record, &block)
        BatchLoader.for(record).batch(key: cache_key(record)) do |records, loader|
          data = []
          records.each do |r|
            value = calculate_value(r)
            data << value
            loader.call(r, value)
          end

          data = data.flatten.compact.uniq
          # TODO: Log stuff
          # log :info, "[record_ids:#{records.map(&:id).join(', ')}]"

          block&.call(data)
        end
      end

      private

      attr_reader :relationship_name, :load_block

      def cache_key(record)
        "#{record.class}/#{relationship_name}"
      end

      def calculate_value(record)
        return record.public_send(relationship_name) unless load_block

        load_block.call(record)
      end
    end
  end
end
