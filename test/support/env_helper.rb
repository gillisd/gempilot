module Support
  module EnvHelper
    extend Forwardable
    include Support::EnvironmentAssertions

    def_delegators :env,
                   :all_files,
                   :all_directories,
                   :touch,
                   :mkdir_p,
                   :ln,
                   :ln_s,
                   :open,
                   :write,
                   :path_for,
                   :chdir,
                   :invoke_task,
                   :in_namespace,
                   :trace,
                   :file,
                   :task,
                   :display_prerequisites

    def self.included(base)
      base.attr_reader :env
    end

    def before_setup
      super
      @env = Support::Environment.create
    end

    def after_teardown
      super
      env.stop
    end
  end
end
