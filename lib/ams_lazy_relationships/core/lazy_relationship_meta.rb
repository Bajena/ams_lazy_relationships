# frozen_string_literal: true

module AmsLazyRelationships::Core
  # Internal helper class for keeping relationship details
  class LazyRelationshipMeta
    # @param name [String/Symbol] lazy relationship name. Can be different than the relationship name
    # @param loader [Object] lazy loader for the relationship. Has to respond to `load(record, &block)`.
    # @param reflection [Object] AMS relationship meta. Keeps data like the serializer for the relationship.
    #   This data structure differs for various AMS versions.
    # @param load_for [Symbol] Optionally you can delegate the loading to
    #   a method defined by `load_for` symbol.
    #   It is useful e.g. when the loaded object is a decorated object and the
    #   real AR model is accessible by calling the decorator's method.
    def initialize(name:, loader:, reflection:, load_for: nil)
      @name = name.to_sym
      @loader = loader
      @reflection = reflection
      @load_for = load_for
    end

    attr_reader :name, :loader, :reflection, :load_for

    # @return [ActiveModel::Serializer] AMS Serializer class for the relationship
    def serializer_class
      return @serializer_class if defined?(@serializer_class)

      @serializer_class =
        if AmsLazyRelationships::Core.ams_version <= Gem::Version.new("0.10.0.rc2")
          reflection[:association_options][:serializer]
        else
          reflection.options[:serializer]
        end
    end
  end
end
