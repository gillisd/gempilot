require "command_kit/inflector"

module Gempilot
  class CLI
    module GemContext
      private

      def detect_gem_context
        gemspec = Dir.glob("*.gemspec").first

        unless gemspec
          puts colors.red("No gemspec found in current directory. Run this from your gem's root.")
          exit 1
        end

        @gem_name = File.basename(gemspec, ".gemspec")
        @gem_module = CommandKit::Inflector.camelize(@gem_name)
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
        return if root == @gem_module

        puts colors.red("Expected constant to start with #{@gem_module}, got #{root}")
        exit 1
      end
    end
  end
end
