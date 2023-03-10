# frozen_string_literal: true

require "ams_lazy_relationships/loaders/base"

module AmsLazyRelationships
  module Loaders
    # Lazy loads (has_one/has_many/has_many_through/belongs_to) ActiveRecord
    # associations for ActiveRecord models
    class Association < Base
      # @param model_class_name [String] The name of AR class for which the
      #   associations are loaded. E.g. When loading comment.blog_post
      #   it'd be "BlogPost".
      # @param association_name [Symbol] The name of association being loaded
      #   E.g. When loading comment.blog_post it'd be :blog_post
      def initialize(model_class_name, association_name)
        @model_class_name = model_class_name
        @association_name = association_name
      end

      private

      attr_reader :model_class_name, :association_name

      def load_data(records, loader)
        preload(records)

        data = []
        records.each do |r|
          value = r.public_send(association_name)
          data << value
          loader.call(r, value)
        end

        data = data.flatten.compact.uniq
      end

      def batch_key(_)
        @batch_key ||= "#{model_class_name}/#{association_name}"
      end

      def preload(records)
        if ::ActiveRecord::VERSION::MAJOR >= 7
          ::ActiveRecord::Associations::Preloader.new(
            records: records_to_preload(records),
            associations: association_name
          ).call
        else
          ::ActiveRecord::Associations::Preloader.new.preload(
            records_to_preload(records), association_name
          )
        end
      end

      def records_to_preload(records)
        # It may happen that same record comes here twice (e.g. wrapped
        # in a decorator and non-wrapped). In this case Associations::Preloader
        # stores duplicated records in has_many relationships for some reason.
        # Calling uniq(&:id) solves the problem.
        #
        # One more case when duplicated records appear in has_many relationships
        # is the recent assignation to `accept_nested_attributes_for` setter.
        # ActiveRecord will not mark the association as `loaded` but in same
        # time will keep internal representation of the nested records created
        # by `accept_nested_attributes_for`. Then Associations::Preloader is
        # going to merge internal state of associated records with the same
        # records recently stored in DB. `r.association(association_name).reset`
        # effectively fixes that.
        records.
          uniq(&:id).
          reject { |r| r.association(association_name).loaded? }.
          each { |r| r.association(association_name).reset }
      end
    end
  end
end
