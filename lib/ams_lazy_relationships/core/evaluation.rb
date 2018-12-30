# frozen_string_literal: true

module AmsLazyRelationships::Core
  # Module responsible for lazy loading the relationships during the runtime
  module Evaluation
    private

    LAZY_NESTING_LEVELS = 3
    NESTING_START_LEVEL = 1

    # Recursively loads the tree of lazy relationships
    # The nesting is limited to 3 levels.
    #
    # @param object [Object] Lazy relationships will be loaded for this record.
    # @param level [Integer] Current nesting level
    def load_all_lazy_relationships(object, level = NESTING_START_LEVEL)
      return if level >= LAZY_NESTING_LEVELS
      return unless object

      return unless lazy_relationships

      lazy_relationships.each_value do |lrm|
        load_lazy_relationship(lrm, object, level)
      end
    end

    # @param lrm [LazyRelationshipMeta] relationship data
    # @param object [Object] Object to load the relationship for
    # @param level [Integer] Current nesting level
    def load_lazy_relationship(lrm, object, level = NESTING_START_LEVEL)
      load_for_object = if lrm.load_for.present?
                          object.public_send(lrm.load_for)
                        else
                          object
                        end

      lrm.loader.load(load_for_object) do |batch_records|
        deep_load_for_yielded_records(
          batch_records,
          lrm,
          level
        )
      end
    end

    def deep_load_for_yielded_records(batch_records, lrm, level)
      # There'll be no more nesting if there's no
      # reflection for this relationship. We can skip deeper lazy loading.
      return unless lrm.reflection

      Array.wrap(batch_records).each do |r|
        lrm.serializer_class.send(:load_all_lazy_relationships, r, level + 1)
      end
    end
  end
end
