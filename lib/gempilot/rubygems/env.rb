module Gempilot
  module Rubygems
    class Env
      def default_gems_dir
        Pathname(Gem.default_specifications_dir)
      end

      def default_gems
        index = all_default_gems.to_h { [it.name, it] }
        Bundler
          .locked_gems
          .specs
          .select { index.key? it.name }
      end

      def all_default_gems
        @all_default_gems ||= begin
          default_gems_dir
            .children
            .map(&:to_s)
            .map { load_spec it }
        end
      end

      private

      def load_spec(body)
        # noinspection RubyMismatchedReturnType
        Gem::Specification.load body
      end
    end
  end
end
