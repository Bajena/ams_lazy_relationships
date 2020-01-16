# frozen_string_literal: true

# There is a general problem inside AMS related to custom association finder
# combined with `include_data` setting:
#
#   class BlogPostSerializer < BaseSerializer
#     belongs_to :category do
#       include_data :if_sideloaded
#       object.categories.last
#     end
#   end
#
# The problem is that `belongs_to` block will be fully evaluated each time for
# each object, and only after that AMS is able to take into account
# `include_data` mode -
# https://github.com/rails-api/active_model_serializers/blob/v0.10.10/lib/active_model/serializer/reflection.rb#L162-L163
#
#   def value(serializer, include_slice)
#     # ...
#     block_value = instance_exec(serializer, &block) if block
#     return unless include_data?(include_slice)
#     # ...
#   end
#
# That causing redundant (and so huge potentially!) SQL queries and AR objects
# allocation when `include_data` appears to be `false` but `belongs_to` block
# defines instant (not a kind of AR::Relation) custom association finder.
#
# Described problem is a very specific use case for pure AMS applications.
# The bad news is that `ams_lazy_relationships` always utilizes the
# association block -
# https://github.com/Bajena/ams_lazy_relationships/blob/v0.2.0/lib/ams_lazy_relationships/core/relationship_wrapper_methods.rb#L32-L36
#
# def define_lazy_association(type, name, options, block)
#   #...
#   block ||= lambda do |serializer|
#     serializer.public_send("lazy_#{name}")
#   end
#
#   public_send(type, name.to_sym, real_relationship_options, &block)
#   #...
# end
#
# This way we break `include_data` optimizations for the host application.
#
# In order to overcome that we are forced to monkey-patch
# `AmsLazyRelationships::Extensions::Reflection#value` method and make it to be
# ready for Proc returned by association block. This way we will use a kind of
#
#   block ||= lambda do |serializer|
#     -> { serializer.public_send("lazy_#{name}") }
#   end
#
# as association block, then AMS will evaluate it, get the value of `include_data`
# setting, make a decision do we need to continue with that association, if so -
# will finally evaluate the proc with lazy relationship inside it.

module AmsLazyRelationships
  module Extensions
    module Reflection
      def value(*)
        case (block_value = super)
        when Proc, Method then block_value.call
        else block_value
        end
      end
    end
  end
end

::ActiveModel::Serializer::Reflection.prepend AmsLazyRelationships::Extensions::Reflection
