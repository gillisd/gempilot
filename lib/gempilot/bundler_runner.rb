module Gempilot
  class BundlerRunner
    include FileUtils

    def initialize(gem_name:, github_user:, executable:, target_path:)
      @gem_name = gem_name
      @github_user = github_user
      @executable = executable
      @target_path = target_path
      @command_buffer = StringIO.new
    end

    def gemspec_path
      Pathname.new(@gem_name)
              .join("#{@gem_name}.gemspec")
              .expand_path
    end

    def install
      chdir @gem_name do
        system('bundle install', out: $stdout, err: $stderr)
      end
    end

    def create_gem
      build_command
      chdir @target_path
      status = system(@command_buffer.string, out: $stdout, err: $stderr)
      if status
        puts "Gem #{@gem_name} created successfully!"
      else
        puts "Failed to create gem #{@gem_name}."
      end
      install
    end

    private

    def build_command
      @command_buffer.tap do |cb|
        cb.write 'bundle gem '
        cb.write "--github-username #{@github_user} "
        cb.write '--exe ' if @executable
        cb.write '--linter=rubocop '
        cb.write @gem_name.to_s
      end
    end
  end
end
