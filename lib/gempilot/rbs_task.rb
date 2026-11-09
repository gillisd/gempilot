require "rake/clean"
require "rake/tasklib"
require_relative "../gempilot"

module Gempilot
  ## Defines rake tasks that install and validate a gem's RBS collection.
  ##
  ##   # Rakefile
  ##   require "gempilot/rbs_task"
  ##   Gempilot::RBSTask.new
  ##
  ##   $ rake rbs:validate
  ##   # It's done! 27 gems' RBSs now installed.
  class RBSTask < Rake::TaskLib
    attr_reader :root

    def initialize(root: Dir.pwd)
      super()
      @root = Pathname(root)
      define_tasks
    end

    def collection_yaml = root / "rbs_collection.yaml"

    def collection_dir = root / ".gem_rbs_collection"

    private

    def define_tasks
      namespace :rbs do
        define_setup_task
        define_clobber_task
        define_validate_task
        namespace(:collection) { define_collection_tasks }
      end
      define_top_level_hooks
    end

    def define_top_level_hooks
      desc "Prepare the development environment" unless Rake::Task.task_defined?(:setup)
      task setup: ["rbs:setup"]
      task clobber: ["rbs:clobber"]
    end

    def define_setup_task
      desc "Install the rbs collection rbs_collection.lock.yaml pins"
      task setup: ["rbs:collection:install"]
    end

    def define_default_gems_task
      desc "Adds default gems in use to the collection"
    end

    def define_clobber_task
      dir = collection_dir
      desc "Remove the installed rbs collection"
      task(:clobber) { rm_rf dir }
    end

    def define_validate_task
      desc "Validate sig/ against the installed collection"
      task(validate: ["rbs:setup"]) { rbs("-I", "sig", "validate") }
    end

    def define_collection_tasks
      define_init_task
      define_collection_command_task(:install, "Install the gem RBS files the collection lists",
                                     ["rbs:collection:init"])
      define_collection_command_task(:update, "Re-resolve the collection and rewrite rbs_collection.lock.yaml")
    end

    def define_init_task
      file(collection_yaml) { rbs_collection "init" }
      desc "Write rbs_collection.yaml if it is missing"
      task init: [collection_yaml]
    end

    def define_collection_command_task(name, description, prerequisites = [])
      desc description
      task(name => prerequisites) { rbs_collection name.to_s }
    end

    def rbs_collection(subcommand)
      rbs("collection", subcommand)
    end

    def rbs(*args)
      Shell.run("bundle", "exec", "rbs", "--collection", collection_yaml.to_s, *args, chdir: root)
    end
  end
end
