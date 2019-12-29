# frozen_string_literal: true

module AmsLazyRelationships
  module Loaders
    # A base class for all the loaders. A correctly defined loader requires
    # the `load_data` and `batch_key` methods.
    class Base
      # Lazy loads and yields the data when evaluating
      # @param record [Object] an object for which we're loading the data
      # @param scope [Object] serialization scope object.
      # @param block [Proc] a block to execute when data is evaluated.
      #  Loaded data is yielded as a block argument.
      def load(record, scope = nil, &block)
        BatchLoader.for(record).batch(
          key: batch_key(record),
          # Replacing methods can be costly, especially on objects with lots
          # of methods (like AR methods). Let's disable it.
          # More info:
          # https://github.com/exAspArk/batch-loader/tree/v1.4.1#replacing-methods
          replace_methods: false
        ) do |records, loader|
          data = load_data(records, loader, scope)

          block&.call(data)
        end
      end

      protected

      # Loads required data for all records gathered by the batch loader.
      # Assigns data to records by calling the `loader` lambda.
      # @param records [Array<Object>] Array of all gathered records.
      # @param loader [Proc] Proc used for assigning the batch loaded data to
      #   records. First argument is the record and the second is the data
      #   loaded for it.
      # @param scope [Object] Serialization scope object.
      # @returns [Array<Object>] Array of loaded objects
      def load_data(_records, _loader, _scope)
        raise "Implement in child"
      end

      # Computes a batching key based on currently evaluated record
      # @param record [Object]
      # @returns [String] Batching key
      def batch_key(_record)
        raise "Implement in child"
      end
    end
  end
end
