require "tmpdir"

Rake.module_eval do
  def application
    Thread.current[:__application]
  end

  def application=(app)
    Thread.current[:__application] = app
  end
end

module Support
  ## Manages a temporary working directory and tracked filesystem objects
  ## for integration tests that need isolated file operations.
  class Environment
    extend Forwardable
    extend Rake::DSL

    TMPDIR_PATTERN = %r{^/(?:private/)?var/folders/}

    attr_reader :workdir, :original_dir

    def_delegators :application, :invoke_task, :in_namespace
    def_delegators :application, :trace, :display_prerequisites
    def_delegators :"self.class", :directory, :task, :file

    def self.create(**kwargs)
      env = new(**kwargs)
      env.start
    end

    def initialize(workdir: Dir.mktmpdir(SecureRandom.alphanumeric(10)))
      super()
      @workdir = wrap_pathname workdir
      @objects = Set.new
      @original_dir = wrap_pathname __dir__
    end

    def application
      ::Rake.application
    end

    def start
      self
    end

    def all_files
      @objects.select(&:file?).to_a
    end

    def all_directories
      @objects.select(&:directory?).to_a
    end

    def all_objects
      @objects.to_a
    end

    def touch(filename)
      path = path_for filename
      mkdir_p path.parent
      add_object path, method: :touch
    rescue Errno::ENOENT
      raise "File not found: #{pathname}"
    end

    def chdir(*args, **kwargs, &)
      FileUtils.chdir(*args, **kwargs, &)
    end

    def mkdir_p(dirname)
      pathname = path_for dirname

      add_object pathname, method: :mkdir_p
    rescue Errno::EEXIST
      # Directory already exists, do nothing
    end

    def path_for(filename)
      input_path = Pathname(filename)
      resolved = (
        if input_path.relative?
          workdir.join(input_path)
        else
          input_path
        end
      )

      resolved
        .expand_path
        .then { |expanded| expanded.exist? ? expanded.realpath : expanded.cleanpath }
    end

    def open_file(filename, mode = "r", &)
      pathname = path_for filename
      mkdir_p pathname.parent
      @objects.add pathname
      pathname.open(mode, &)
    rescue Errno::ENOENT
      raise "File not found: #{pathname.to_path}"
    end

    def ln(source, target, **kwargs)
      source_path = path_for source
      target_path = path_for target

      mkdir_p target_path.parent
      @objects.add target_path
      FileUtils.ln source_path, target_path, **kwargs
    rescue Errno::ENOENT
      raise "File not found: #{source_path.to_path}"
    end

    def ln_s(source, target, **kwargs)
      source_path = path_for source
      target_path = path_for target

      mkdir_p target_path.parent
      @objects.add target_path
      FileUtils.ln_s source_path, target_path, **kwargs
    rescue Errno::ENOENT
      raise "File not found: #{source_path.to_path}"
    rescue Errno::EEXIST
      # Symlink already exists, do nothing
    end

    def write(filename, content)
      open_file(filename, "w") do |file|
        file.write content
      end
    rescue Errno::ENOENT
      raise "File not found: #{pathname.to_path}"
    end

    def safe_unlink(object)
      remove_object object, method: :safe_unlink
    end

    def rm_rf(object)
      remove_object object, method: :rm_rf
    end

    def rm_f(object)
      remove_object object, method: :rm_f
    end

    def rm(object)
      remove_object object, method: :rm
    end

    def rmdir(object)
      remove_object object, method: :rmdir
    end

    def stop
      cleanup_tracked_objects
      remove_workdir
      Rake.application = nil
    end

    def wrap_pathname(object)
      expanded = Pathname.new(object)
                         .expand_path

      return expanded.realpath if expanded.exist?

      expanded
    end

    private

    def cleanup_tracked_objects
      @objects.each do |object|
        case [object.file?, object.directory?, object.exist?]
        in true, false, true
          safe_unlink object
        in false, true, true
          rm_rf object
        in false, false, false
          nil
        else
          raise "Unexpected pathname #{object} is not a file or directory. This is a bug."
        end
      end
    end

    def remove_workdir
      FileUtils.rmdir workdir
    rescue Errno::ENOTEMPTY, Errno::ENOENT
      nil
    end

    def remove_object(object, method:)
      path = wrap_pathname(object)
      raise ArgumentError, "I do not manage #{path}" unless @objects.member?(path)

      if safe_operation?(path)
        FileUtils.send(method, path)
      else
        abort_unsafe_operation(object, method)
      end
    end

    def add_object(object, method:)
      path = wrap_pathname(object)

      if safe_operation?(path)
        @objects.add wrap_pathname(object)
        FileUtils.send(method, object)
      else
        abort_unsafe_operation(object, method)
      end
    end

    def abort_unsafe_operation(object, method)
      warn "UNSAFE OPERATION BLOCKED. THIS IS A BUG."
      warn "OBJECT: #{object}"
      warn "METHOD: #{method}"
      warn "OBJECTS: #{@objects.to_a.join("\n")}"
      warn caller
      exit 1
    end

    def safe_operation?(path)
      path.to_s.match?(TMPDIR_PATTERN)
    end
  end
end
