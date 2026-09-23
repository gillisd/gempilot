module Gempilot
  ##
  # The Zeitwerk loader that manages a project's autoload root, located
  # through Zeitwerk's loader registry once the project has been required.
  #
  # Zeitwerk knows which loader owns a directory, and a project's constant
  # names are an inflection performed by that loader, not the other way
  # around. Looking the loader up by directory therefore keeps the project's
  # own inflections in charge: a gem whose entry point sets up +ECS+ rather
  # than +Ecs+ is found without anyone guessing its module name.
  class ProjectLoader
    ##
    # Raised when no registered loader manages the directory.
    class NotFound < Error; end

    ##
    # Absolute, symlink-resolved path of the directory the loader must manage.
    attr_reader :root_dir

    def initialize(root_dir)
      @root_dir = File.realpath(root_dir)
    end

    ##
    # Returns the registered loader whose root directories include
    # +root_dir+, raising NotFound when there is none.
    def loader
      @loader ||= registered_loaders.find { manages?(it) } || raise(NotFound, not_found_message)
    end

    private

    def manages?(loader)
      loader.dirs.any? { File.realpath(it) == root_dir }
    end

    def registered_loaders
      Zeitwerk::Registry.loaders.to_enum(:each)
    end

    def not_found_message
      "No Zeitwerk loader manages #{root_dir}; set one up with Zeitwerk::Loader.for_gem"
    end
  end
end
