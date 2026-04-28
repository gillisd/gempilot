module Gempilot
  class TestEnv
    attr_reader :loader, :test_root

    def self.setup(dir = caller_dir(caller_locations))
      new(dir).tap do |e|
        require e.project.lib_entrypoint
        yield e
        e.setup
      end
    end

    def self.caller_dir(caller_locations)
      caller = caller_locations.first

      caller_path = caller
        .to_s
        .split(/:[0-9]+/)
        .first

      Pathname(caller_path)
        .expand_path
        .parent
    end

    private_class_method :caller_dir


    def initialize(test_root, loader: Zeitwerk::Loader.new)
      @test_root = Pathname(test_root).expand_path
      @loader = loader.tap do |l|
        l.tag = self.class.name
      end
    end

    def project
      Project.new @test_root.parent
    end

    def loader_inflect(...)
      @loader.inflector.inflect(...)
    end

    def setup
      @loader.tap do |l|
        l.ignore "**/*_spec.rb"
        l.ignore "*_spec.rb"
        p test_root
        l.push_dir test_root
        l.setup
      end
    end
  end
end
