# frozen_string_literal: true

module AmsLazyRelationships::Core
  class LazyRelationshipMeta
    def initialize(name:, loader:, reflection:, load_for: nil)
      @name = name.to_sym
      @loader = loader
      @reflection = reflection
      @load_for = load_for
    end

    attr_reader :name, :loader, :reflection, :load_for

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
