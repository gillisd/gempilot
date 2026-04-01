require "command_kit/inflector"

module Gempilot
  class CLI
    ## Shared context for commands that operate inside an existing gem.
    module GemContext
      private

      def detect_gem_context
        gemspec = Dir.glob("*.gemspec").first

        unless gemspec
          puts colors.red("No gemspec found in current directory. Run this from your gem's root.")
          exit 1
        end

        @gem_name = File.basename(gemspec, ".gemspec")
        @require_path = @gem_name.tr("-", "/")
        @gem_module = CommandKit::Inflector.camelize(@require_path)
        @test_framework = File.directory?("spec") ? :rspec : :minitest
      end

      def parse_constant(constant)
        parts = constant.split("::")
        namespaces = parts[0...-1]
        name = parts.last
        segments = parts.map { |p| CommandKit::Inflector.underscore(p) }
        [namespaces, name, segments]
      end

      def validate_gem_root!(root)
        expected = @gem_module.split("::").first
        return if root == expected

        puts colors.red("Expected constant to start with #{expected}, got #{root}")
        exit 1
      end
    end
  end
end
