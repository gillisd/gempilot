
require "bundler/setup"
require "bundler/gem_tasks"
require "rubocop/rake_task"
Bundler::GemHelper.install_tasks name: "gempilot"

require "minitest/test_task"
Minitest::TestTask.create

RuboCop::RakeTask.new

task default: [:test, :rubocop]
