# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ams_lazy_relationships/version"

Gem::Specification.new do |spec|
  spec.name          = "ams_lazy_relationships"
  spec.version       = AmsLazyRelationships::VERSION
  spec.authors       = ["Jan Bajena"]

  spec.summary       = "ActiveModel Serializers addon for eliminating N+1 queries problem from the serializers."
  spec.homepage      = "https://github.com/Bajena/ams_lazy_relationships"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/Bajena/ams_lazy_relationships"
    spec.metadata["changelog_uri"] = "https://github.com/Bajena/ams_lazy_relationships/CHANGELOG.md"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "active_model_serializers"
  spec.add_dependency "batch-loader", "~> 1.2"

  spec.add_development_dependency "activerecord"
  # A Ruby library for testing against different versions of dependencies
  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "bundler", "~> 1.17"
  # Rspec matchers for SQL query counts
  spec.add_development_dependency "db-query-matchers"
  spec.add_development_dependency "github_changelog_generator"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-nav"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-rails", "~> 3.5"
  spec.add_development_dependency "rubocop", "= 0.61.0"
  spec.add_development_dependency "rubocop-rspec", "= 1.20.1"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-lcov"
  spec.add_development_dependency "sqlite3", "~> 1.3"
  # Detect untested code blocks in recent changes
  spec.add_development_dependency "undercover"
  # Dynamically build an Active Record model (with table) within a test context
  spec.add_development_dependency "with_model", "~> 2.0"
end
