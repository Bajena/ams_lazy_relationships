# frozen_string_literal: true

require "ams_lazy_relationships/core/lazy_relationship_meta"

# This module defines a set of methods useful for eliminating N+1 query problem
# during the serialization. Serializers will first prepare a tree of "promises"
# for every nested lazy relationship. The relationship promises will be
# evaluated only when they're requested.
# E.g. when including `comments.user`: instead of loading a user for each comment
# separately it'll gather the comments and load all their users at once
# when including the users in the response.
module AmsLazyRelationships::Core
  LAZY_NESTING_LEVELS = 3
  NESTING_START_LEVEL = 1

  def self.ams_version
    @_ams_version ||= Gem::Version.new(ActiveModel::Serializer::VERSION)
  end

  def self.included(klass)
    klass.send :extend, ClassMethods
    klass.send :prepend, Initializer

    # # Convenience methods - wraps `has_many/belongs_to/has_one` and defines a
    # lazy_has_many, lazy_has_one and lazy_belongs_to.
    #
    # Calling lazy_has_one in your serializer class will:
    # - define a lazy_relationship
    # - define a has_one relationship
    #
    # You can optionally pass a block, just like in standard AMS relationships
    # If block is not present it'll call `lazy_xxx` method where `xxx` is the
    # name of the relationship.
    %i[has_many belongs_to has_one].each do |relationship_type|
      klass.define_singleton_method(
        "lazy_#{relationship_type}"
      ) do |relationship_name, options = {}, &block|
        define_lazy_association(
          relationship_type, relationship_name, options, block
        )
      end
    end
  end

  module ClassMethods
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
        self.class.load_lazy_relationship(lrm, object)
      end
    end

    # End of public interface

    attr_reader :lazy_relationships

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
        lrm.serializer_class.load_all_lazy_relationships(r, level + 1)
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

    def find_reflection(name)
      version = AmsLazyRelationships::Core.ams_version

      # In 0.10.3 this private API has changed again
      return _reflections[name.to_sym] if version >= Gem::Version.new("0.10.3")

      # In 0.10.0.rc2 this private API has changed
      return _reflections.find { |r| r.name.to_sym == name.to_sym } if version >= Gem::Version.new("0.10.0.rc2")

      _associations[name.to_sym]
    end
  end

  module Initializer
    def initialize(*)
      super

      self.class.load_all_lazy_relationships(object)
    end
  end
end
