require "rake/tasklib"
require_relative "../gempilot"

module Gempilot
  ## Rake tasks for validating and inspecting a gem's Zeitwerk loader.
  ##
  ## Owned by gempilot and consumed by generated gems via
  ## <tt>require "gempilot/zeitwerk_task"; Gempilot::ZeitwerkTask.new</tt>, so
  ## the logic rolls forward on a gempilot bump instead of being copied into
  ## every gem's Rakefile. Each task boots a clean child process so eager
  ## loading surfaces naming errors without polluting the Rake process.
  class ZeitwerkTask < Rake::TaskLib
    attr_reader :project

    def initialize(root: Dir.pwd)
      super()
      @project = Project.new(root)
      define_tasks
    end

    private

    def define_tasks
      namespace :zeitwerk do
        define_validate_task
        define_all_task
      end
    end

    def define_validate_task
      desc "Verify all files follow Zeitwerk naming conventions"
      task(:validate) { ruby "-Ilib", "-e", validate_script }
    end

    def define_all_task
      desc "List every constant Zeitwerk manages and the file it expects"
      task(:all) { ruby "-Ilib", "-e", all_script }
    end

    def loader
      "#{project.module_name}::LOADER"
    end

    def validate_script
      <<~RUBY
        require '#{project.require_path}'
        #{loader}.eager_load(force: true)
        puts 'Zeitwerk: All files loaded successfully.'
      RUBY
    end

    def all_script
      <<~RUBY
        require '#{project.require_path}'
        rows = #{loader}.all_expected_cpaths.sort_by(&:last)
        width = rows.map { |_path, cpath| cpath.length }.max || 0
        rows.each { |path, cpath| puts format("%-\#{width}s  %s", cpath, path) }
      RUBY
    end
  end
end
