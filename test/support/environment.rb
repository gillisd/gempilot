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
  class Environment
    extend Forwardable
    extend Rake::DSL

    attr_reader :workdir, :original_dir

    def_delegators :application, :invoke_task, :in_namespace
    def_delegators :application, :trace, :display_prerequisites
    def_delegators :"self.class", :directory, :task, :file

    def self.create(**)
      env = new(**)
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

    def chdir(...)
      FileUtils.chdir(...)
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
        .then { |it| it.exist? ? it.realpath : it.cleanpath }
    end

    def open(filename, mode = "r", &)
      pathname = path_for filename
      mkdir_p pathname.parent
      @objects.add pathname
      pathname.open(mode, &)
    rescue Errno::ENOENT
      raise "File not found: #{pathname.to_path}"
    end

    def ln(source, target, **)
      source_path = path_for source
      target_path = path_for target

      mkdir_p target_path.parent
      @objects.add target_path
      FileUtils.ln(source_path, target_path, **)
    rescue Errno::ENOENT
      raise "File not found: #{source_path.to_path}"
    end

    def ln_s(source, target, **)
      source_path = path_for source
      target_path = path_for target

      mkdir_p target_path.parent
      @objects.add target_path
      FileUtils.ln_s(source_path, target_path, **)
    rescue Errno::ENOENT
      raise "File not found: #{source_path.to_path}"
    rescue Errno::EEXIST
      # Symlink already exists, do nothing
    end

    def write(filename, content)
      pathname = path_for filename
      mkdir_p pathname.parent
      @objects.add pathname
      pathname.open("w") { |f| f.write content }
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
      @objects.each do |object|
        case [object.file?, object.directory?, object.exist?]
        in true, false, true
          safe_unlink object
        in false, true, true
          rm_rf object
        in false, false, false
          # pass
        else
          raise "Unexpected pathname #{object} is not a file or directory. This is a bug."
        end
      end

      begin
        FileUtils.rmdir workdir
      rescue StandardError
        nil
      end
      Rake.application = nil
    end

    def wrap_pathname(object)
      expanded = Pathname
        .new(object)
        .expand_path
      if expanded.exist?
        return expanded.realpath
      end

      expanded
    end

    # def invoke_task(name, *args)
    #   task = lookup(name.to_sym)
    #   task.invoke(*args)
    # end

    private

    def remove_object(object, method:)
      if (path = wrap_pathname(object)) && @objects.member?(path)
        if safe_operation?(path)
          FileUtils.send(method, path)
        else
          warn "YOU ALMOST DELETED YOUR PROJECT DIR. THERE IS A BUG."
          warn
          warn "OBJECT: #{object}"
          warn "METHOD: #{method}"
          warn
          warn "OBJECTS: #{@objects.to_a.join("\n")}"
          warn
          warn caller
          exit 1
        end
        return
      end

      raise ArgumentError, "I do not manage #{path}"
    end

    def add_object(object, method:)
      if (path = wrap_pathname(object)) && safe_operation?(path)
        @objects.add wrap_pathname(object)
        FileUtils.send(method, object)
      else
        warn "You tried to add a file to your project dir. THIS IS A BUG."
        warn
        warn "OBJECT: #{object}"
        warn "METHOD: #{method}"
        warn
        warn "OBJECTS: #{@objects.to_a.join("\n")}"
        warn
        warn caller
        exit 1
      end
    end

    def safe_operation?(path)
      path.to_s.match?(%r{^/(?:private/)?var/folders/})
    end

    def save_rakefile
      touch "Rakefile"
    end
  end
end
