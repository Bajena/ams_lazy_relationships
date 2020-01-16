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
          define_lazy_association(relationship_type, relationship_name, options, block)
        end
      end
    end

    def define_lazy_association(type, name, options, block)
      lazy_relationship_option_keys = %i[load_for loader]

      real_relationship_options = options.except(*lazy_relationship_option_keys)

      public_send(type, name.to_sym, real_relationship_options) do |serializer|
        block_value = instance_exec(serializer, &block) if block

        if block && block_value != :nil
          # respect the custom finder for lazy association
          # @see https://github.com/rails-api/active_model_serializers/blob/v0.10.10/lib/active_model/serializer/reflection.rb#L165-L168
          block_value
        else
          # provide default lazy association finder in a form of lambda,
          # in order to play nice with possible `include_data` setting.
          # @see lib/ams_lazy_relationships/extensions/reflection.rb
          serializer.method("lazy_#{name}")
        end
      end

      lazy_relationship(name, options.slice(*lazy_relationship_option_keys))
    end
  end
end
