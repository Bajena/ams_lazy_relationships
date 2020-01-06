# frozen_string_literal: true

require "ams_lazy_relationships/core/lazy_relationship_method"
require "ams_lazy_relationships/core/lazy_dig_method"
require "ams_lazy_relationships/core/relationship_wrapper_methods"
require "ams_lazy_relationships/core/evaluation"

# This module defines a set of methods useful for eliminating N+1 query problem
# during the serialization. Serializers will first prepare a tree of "promises"
# for every nested lazy relationship. The relationship promises will be
# evaluated only when they're requested.
# E.g. when including `comments.user`: instead of loading a user for each comment
# separately it'll gather the comments and load all their users at once
# when including the users in the response.
module AmsLazyRelationships::Core
  def self.ams_version
    @_ams_version ||= Gem::Version.new(ActiveModel::Serializer::VERSION)
  end

  def self.included(klass)
    klass.send :extend, ClassMethods
    klass.send :include, LazyDigMethod
    klass.send :prepend, Initializer

    klass.send(:define_relationship_wrapper_methods)
  end

  module ClassMethods
    include LazyRelationshipMethod
    include RelationshipWrapperMethods
    include Evaluation

    def inherited(subclass)
      super

      return unless @lazy_relationships

      subclass.instance_variable_set(
        :@lazy_relationships, @lazy_relationships.clone
      )
    end

    private

    # lazy_relationships [Array<AmsLazyRelationships::Core::LazyRelationshipMeta>]
    attr_reader :lazy_relationships
  end

  module Initializer
    def initialize(*)
      super

      self.class.send(:init_all_lazy_relationships, object)
    end
  end
end
