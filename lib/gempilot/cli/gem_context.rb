module Gempilot
  class CLI
    ## Shared context for commands that operate inside an existing gem.
    module GemContext
      using String::Inflectable

      private

      def detect_gem_context
        gemspec = Dir.glob("*.gemspec").first

        unless gemspec
          puts colors.red("No gemspec found in current directory. Run this from your gem's root.")
          exit 1
        end

        @gem_name = File.basename(gemspec, ".gemspec")
        @require_path = @gem_name.tr("-", "/")
        @gem_module = @require_path.camelize
        @test_framework = File.directory?("spec") ? :rspec : :minitest
      end

      def gem_constant(input)
        GemConstant.new(input: input, gem_module: @gem_module, require_path: @require_path)
      end
    end
  end
end
