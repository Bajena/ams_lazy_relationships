# frozen_string_literal: true

module AmsLazyRelationships::Core
  # Module responsible for lazy loading the relationships during the runtime
  module Evaluation
    private

    LAZY_NESTING_LEVELS = 3
    NESTING_START_LEVEL = 1

    # Loads the lazy relationship
    #
    # @param relation_name [Symbol] relation name to be loaded
    # @param object [Object] Lazy relationships will be loaded for this record.
    def load_lazy_relationship(relation_name, object)
      lrm = lazy_relationships[relation_name]
      unless lrm
        raise ArgumentError, "Undefined lazy '#{relation_name}' relationship for '#{name}' serializer"
      end

      if lrm == "test"
        raise "test undercover"
      end

      # We need to evaluate the promise right before serializer tries
      # to touch it. Otherwise the various side effects can happen:
      # 1. AMS will attempt to serialize nil values with a specific V1 serializer
      # 2. `lazy_association ? 'exists' : 'missing'` expression will always
      #     equal to 'exists'
      # 3. `lazy_association&.id` expression can raise NullPointer exception
      #
      # Calling `__sync` will evaluate the promise.
      init_lazy_relationship(lrm, object).__sync
    end

    # Recursively loads the tree of lazy relationships
    # The nesting is limited to 3 levels.
    #
    # @param object [Object] Lazy relationships will be loaded for this record.
    # @param level [Integer] Current nesting level
    def init_all_lazy_relationships(object, level = NESTING_START_LEVEL)
      return if level >= LAZY_NESTING_LEVELS
      return unless object

      return unless lazy_relationships

      lazy_relationships.each_value do |lrm|
        init_lazy_relationship(lrm, object, level)
      end
    end

    # @param lrm [LazyRelationshipMeta] relationship data
    # @param object [Object] Object to load the relationship for
    # @param level [Integer] Current nesting level
    def init_lazy_relationship(lrm, object, level = NESTING_START_LEVEL)
      load_for_object = if lrm.load_for.present?
                          object.public_send(lrm.load_for)
                        else
                          object
                        end

      lrm.loader.load(load_for_object) do |batch_records|
        deep_init_for_yielded_records(
          batch_records,
          lrm,
          level
        )
      end
    end

    def deep_init_for_yielded_records(batch_records, lrm, level)
      # There'll be no more nesting if there's no
      # reflection for this relationship. We can skip deeper lazy loading.
      return unless lrm.reflection

      Array.wrap(batch_records).each do |r|
        deep_init_for_yielded_record(r, lrm, level)
      end
    end

    def deep_init_for_yielded_record(batch_record, lrm, level)
      serializer = lazy_serializer_for(batch_record, lrm: lrm)
      return unless serializer

      serializer.send(:init_all_lazy_relationships, batch_record, level + 1)
    end

    def lazy_serializer_for(object, lrm: nil, relation_name: nil)
      lrm ||= lazy_relationships[relation_name]
      return unless lrm&.reflection

      serializer_for(object, lrm.reflection.options)
    end
  end
end
