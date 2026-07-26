module Gempilot
  class Betterleaks
    ## A file the betterleaks integration provides by copying one of gempilot's
    ## templates into the gem, optionally marking it executable. Idempotent: an
    ## existing destination is left untouched.
    class Template
      attr_reader :source, :dest, :executable

      def initialize(source:, dest:, executable: false)
        @source = source
        @dest = dest
        @executable = executable
      end

      def install(generator)
        return generator.skip(dest) if File.exist?(dest)

        generator.mkdir(File.dirname(dest))
        generator.cp(source, dest)
        generator.chmod("+x", dest) if executable
      end
    end
  end
end
