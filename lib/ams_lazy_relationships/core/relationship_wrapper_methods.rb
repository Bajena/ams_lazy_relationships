# frozen_string_literal: true

module AmsLazyRelationships::Core
  # Defines convenience methods - wraps `has_many/belongs_to/has_one` and defines a
  # lazy_has_many, lazy_has_one and lazy_belongs_to.
  #
  # Calling lazy_has_one in your serializer class will:
  # - define a lazy_relationship
  # - define a has_one relationship
  #
  # You can optionally pass a block, just like in standard AMS relationships
  # If block is not present it'll call `lazy_xxx` method where `xxx` is the
  # name of the relationship.
  module RelationshipWrapperMethods
    private

    def define_relationship_wrapper_methods
      %i[has_many belongs_to has_one].each do |relationship_type|
        define_singleton_method(
          "lazy_#{relationship_type}"
        ) do |relationship_name, options = {}, &block|
          send(:define_lazy_association, relationship_type, relationship_name, options, block)
        end
      end
    end

    def define_lazy_association(type, name, options, block)
      lazy_relationship_option_keys = %i[load_for loader]

      real_relationship_options = options.except(*lazy_relationship_option_keys)

      block ||= lambda do |serializer|
        # We need to evaluate the promise right before AMS tries
        # to serialize it. Otherwise AMS will attempt to serialize nil values
        # with a specific V1 serializer.
        # Calling `itself` will evaluate the promise.
        serializer.public_send("lazy_#{name}").tap(&:itself)
      end

      public_send(type, name.to_sym, real_relationship_options, &block)

      lazy_relationship(name, options.slice(*lazy_relationship_option_keys))
    end
  end
end
