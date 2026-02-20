module Support
  module EnvironmentAssertions
    def assert_path_exists(path, msg = nil)
      absolute = expand_path path
      super(absolute, msg)
    end

    def assert_task_defined(task_name)
      assert ::Rake::Task.task_defined?(task_name), "Expected task #{task_name} to be defined"
    end

    def refute_task_defined(task_name)
      refute ::Rake::Task.task_defined?(task_name), "Expected task #{task_name} to not be defined"
    end

    def assert_file_contains(filename, content)
      file_content = expand_path(filename).read

      assert_includes file_content, content, "Expected #{filename} to contain #{content}"
    end

    private

    def expand_path(object)
      object_pathname = Pathname.new(object)
      if object_pathname.relative?
        workdir.join(object_pathname).expand_path
      else
        object_pathname.expand_path
      end
    end

    def workdir
      if respond_to? :env
        env.workdir
      else
        Pathname.pwd
      end
    end
  end
end
