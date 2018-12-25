require "simplecov"
require "simplecov-lcov"

SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
SimpleCov.start do
  add_filter(/^\/spec\//)
end

require "bundler/setup"
require "ams_lazy_relationships"

require "undercover"
require "with_model"
require "batch-loader"
require "pry"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.extend WithModel

  config.before(:all) do
    ActiveRecord::Base.establish_connection(
      "adapter"  => "sqlite3",
      "database" => ":memory:"
    )
  end

  config.after do
    BatchLoader::Executor.clear_current
  end
end

