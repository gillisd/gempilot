require "rake/clean"
require "rake/tasklib"

module Gempilot
  ## Rake tasks for managing a gem's RBS collection.
  ##
  ## Consumed via <tt>require "gempilot/rbs_task"; Gempilot::RBSTask.new</tt>.
  ## Wraps <tt>rbs collection</tt>: +rbs_collection.yaml+ lists the gems whose
  ## signatures to fetch, +rbs_collection.lock.yaml+ pins them, and the
  ## signatures install into +.gem_rbs_collection+. The gem's bundle must
  ## include +rbs+.
  ##
  ## Hooks into the top-level task tree: +setup+ (run by <tt>bin/setup</tt>)
  ## depends on +rbs:setup+, and +clobber+ depends on +rbs:clobber+.
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

    def define_clobber_task
      dir = collection_dir
      desc "Remove the installed rbs collection"
      task(:clobber) { rm_rf dir }
    end

    def define_validate_task
      desc "Validate the RBS signatures against the installed collection"
      task(validate: ["rbs:setup"]) { sh "bundle", "exec", "rbs", "validate", chdir: root.to_s }
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
      sh "bundle", "exec", "rbs", "collection", subcommand, chdir: root.to_s
    end
  end
end
