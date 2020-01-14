# frozen_string_literal: true

require "batch-loader"

# That is a missing dependency of AMS v0.10.0.rc4 in fact (
require "active_support/core_ext/string/inflections"
require "active_model_serializers"

require "ams_lazy_relationships/version"
require "ams_lazy_relationships/loaders"
require "ams_lazy_relationships/core"

module AmsLazyRelationships
end
