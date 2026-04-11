require "bundler/gem_tasks"
Bundler::GemHelper.install_tasks name: "gempilot"

require "minitest/test_task"
Minitest::TestTask.create

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

require_relative 'lib/gempilot'

namespace :spec do
  desc "Prints the specification suite in documentation format and exits"
  task :print do
    exec("rspec", "--format", "documentation", "--dry-run")
  end
end

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

require "rubocop/rake_task"
RuboCop::RakeTask.new do |t|
  t.patterns = [
    'lib/*.rb',
    'lib/**/*.rb',
    'spec/*.rb',
    'spec/**/*.rb',
    'test/*.rb',
    'test/**/*.rb',
  ]
end

Gempilot::VersionTask.new

task default: [:test, :spec, :rubocop]
