require "rake/tasklib"
require_relative "../gempilot"

module Gempilot
  ##
  # Rake tasks for validating and inspecting a gem's Zeitwerk loader.
  #
  # Owned by gempilot and consumed by generated gems, whose Rakefile requires
  # <tt>gempilot/zeitwerk_task</tt> and instantiates <tt>Gempilot::ZeitwerkTask.new</tt>,
  # so the logic rolls forward on a gempilot bump instead of being copied into
  # every gem's Rakefile.
  #
  # Each task boots a clean child process that requires the gem and then asks
  # Zeitwerk for the loader managing the gem's autoload root (see
  # ProjectLoader). The gem's own inflections stay in charge, so a gem whose
  # entry point sets up +ECS+ rather than +Ecs+ validates like any other, and
  # eager loading never pollutes the Rake process.
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

    def loader_script
      <<~RUBY
        require "gempilot"
        require #{project.require_path.inspect}
        loader = Gempilot::ProjectLoader.new(#{project.autoload_root.to_s.inspect}).loader
      RUBY
    end

    def validate_script
      <<~RUBY
        #{loader_script}
        loader.eager_load(force: true)
        puts "Zeitwerk: All files loaded successfully."
      RUBY
    end

    def all_script
      <<~RUBY
        #{loader_script}
        rows = loader.all_expected_cpaths.sort_by(&:last)
        width = rows.map { |_path, cpath| cpath.length }.max || 0
        rows.each { |path, cpath| puts format("%-\#{width}s  %s", cpath, path) }
      RUBY
    end
  end
end
