require "bundler/setup"
require "bundler/gem_tasks"
require "rubocop/rake_task"
Bundler::GemHelper.install_tasks name: "gempilot"

require "minitest/test_task"
Minitest::TestTask.create

RuboCop::RakeTask.new

multitask test_rubocop: [:test, :rubocop]

task safe_build: [:test_rubocop, :build]

task default: [:safe_build]
