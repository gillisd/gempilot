require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
Bundler::GemHelper.install_tasks name: "gempilot"

require "minitest/test_task"
Minitest::TestTask.create

RSpec::Core::RakeTask.new(:spec)

namespace :spec do
  desc "Prints the specification suite in documentation format and exits"
  task :print do
    exec("--format", "documentation", "--dry-run")
  end
end

RuboCop::RakeTask.new

namespace :zeitwerk do
  desc "Verify all files follow Zeitwerk naming conventions"
  task :validate do
    ruby "-e", <<~RUBY
      require 'gempilot'
      Gempilot::LOADER.eager_load(force: true)
      puts 'Zeitwerk: All files loaded successfully.'
    RUBY
  end
end

task default: [:test, :spec, :rubocop]
