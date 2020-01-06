# frozen_string_literal: true

module AmsLazyRelationships::Core
  # Provides `lazy_dig` as an instance method for serializers, in order to make
  # possible to dig relationships in depth just like `Hash#dig` do, keeping the
  # laziness and N+1-free evaluation.
  module LazyDigMethod
    # @param relation_names [Array<Symbol>] the sequence of relation names
    #   to dig through.
    # @return [ActiveRecord::Base, Array<ActiveRecord::Base>, nil] ActiveRecord
    #   objects found by digging through the sequence of nested relationships.
    #   Singular or plural nature of returned value depends from the
    #   singular/plural nature of the chain of relation_names.
    #
    # @example
    #   class AuthorSerializer < BaseSerializer
    #     lazy_belongs_to :address
    #     lazy_has_many :rewards
    #   end
    #
    #   class BlogPostSerializer < BaseSerializer
    #     lazy_belongs_to :author
    #
    #     attribute :author_address do
    #       # returns single AR object or nil
    #       lazy_dig(:author, :address)&.full_address
    #     end
    #
    #     attribute :author_rewards do
    #       # returns an array of AR objects
    #       lazy_dig(:author, :rewards).map(&:description)
    #     end
    #   end
    def lazy_dig(*relation_names)
      relationships = {
        multiple: false,
        data: [{
          serializer: self.class,
          object: object
        }]
      }

      relation_names.each do |relation_name|
        lazy_dig_relationship!(relation_name, relationships)
      end

      objects = relationships[:data].map { |r| r[:object] }

      relationships[:multiple] ? objects : objects.first
    end

    private

    def lazy_dig_relationship!(relation_name, relationships)
      relationships[:data].map! do |serializer:, object:|
        next_objects = lazy_dig_next_objects!(relation_name, serializer, object)
        next unless next_objects

        relationships[:multiple] ||= next_objects.respond_to?(:to_ary)

        lazy_dig_next_relationships!(relation_name, serializer, next_objects)
      end

      relationships[:data].flatten!
      relationships[:data].compact!
    end

    def lazy_dig_next_objects!(relation_name, serializer, object)
      serializer&.send(
        :load_lazy_relationship,
        relation_name,
        object
      )
    end

    def lazy_dig_next_relationships!(relation_name, serializer, next_objects)
      Array.wrap(next_objects).map do |next_object|
        next_serializer = serializer.send(
          :lazy_serializer_for,
          next_object,
          relation_name: relation_name
        )

        {
          serializer: next_serializer,
          object: next_object
        }
      end
    end
  end
end
