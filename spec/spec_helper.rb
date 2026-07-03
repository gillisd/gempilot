require "rake"
require "tmpdir"
require_relative "../lib/gempilot"

COMMAND_SPEC_PATH = %r{/spec/gempilot/cli/commands/}

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.register_ordering(:alphabetical) do |items|
    items.sort_by(&:description)
  end

  config.define_derived_metadata(file_path: COMMAND_SPEC_PATH) do |meta|
    meta[:tmpdir] = true unless meta.key?(:tmpdir)
  end

  config.around(:example, :tmpdir) do |example|
    Dir.mktmpdir("gempilot_spec") do |dir|
      Dir.chdir(dir) { example.run }
    end
  end
end
