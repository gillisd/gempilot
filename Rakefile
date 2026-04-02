require "bundler/setup"
require "bundler/gem_tasks"
require "rubocop/rake_task"
Bundler::GemHelper.install_tasks name: "gempilot"

require "minitest/test_task"
Minitest::TestTask.create

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new

task default: [:test, :spec, :rubocop]
