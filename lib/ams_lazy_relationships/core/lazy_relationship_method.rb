# frozen_string_literal: true

require "ams_lazy_relationships/core/lazy_relationship_meta"

module AmsLazyRelationships::Core
  module LazyRelationshipMethod
    # This method defines a new lazy relationship on the serializer and a method
    # with `lazy_` prefix.
    #
    # @param name [Symbol] The name of the lazy relationship. It'll be used
    #   to define lazy_ method.
    #
    # @param loader [Object] An object responding to `load(record)` method.
    #   By default the AR association loader is used.
    #   The loader should either lazy load (e.g. use BatchLoader) the data or
    #   perform a very light action, because it might be called more than once
    #   when serializing the data.
    #
    # @param load_for [Symbol] Optionally you can delegate the loading to
    #   a method defined by `load_for` symbol.
    #   It is useful e.g. when the loaded object is a decorated object and the
    #   real AR model is accessible by calling the decorator's method.
    def lazy_relationship(name, loader: nil, load_for: nil)
      @lazy_relationships ||= {}

      name = name.to_sym

      loader ||= begin
        current_model_class = self.name.demodulize.gsub("Serializer", "")
        AmsLazyRelationships::Loaders::Association.new(current_model_class, name)
      end

      lrm = LazyRelationshipMeta.new(
        name: name,
        loader: loader,
        reflection: find_reflection(name),
        load_for: load_for
      )
      @lazy_relationships[name] = lrm

      define_method :"lazy_#{name}" do
        self.class.send(:load_lazy_relationship, lrm, self)
      end
    end

    private

    def find_reflection(name)
      version = AmsLazyRelationships::Core.ams_version

      # In 0.10.3 this private API has changed again
      return _reflections[name] if version >= Gem::Version.new("0.10.3")

      # In 0.10.0.rc2 this private API has changed
      return _reflections.find { |r| r.name.to_sym == name } if version >= Gem::Version.new("0.10.0.rc2")

      _associations[name]
    end
  end
end
