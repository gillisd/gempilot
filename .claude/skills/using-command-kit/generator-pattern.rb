# Generator mixin following ronin-core's Core::CLI::Generator pattern.
# Provides template_dir, mkdir, erb, cp, sh wrappers with colored output.
# See: ronin-core/lib/ronin/core/cli/generator.rb

module MyTool
  class CLI
    module Generator
      include CommandKit::Colors
      include CommandKit::FileUtils

      def self.included(command)
        command.extend ClassMethods
      end

      module ClassMethods
        def template_dir(path = nil)
          if path
            @template_dir = File.expand_path(path)
          else
            @template_dir || (superclass.template_dir if superclass.respond_to?(:template_dir))
          end
        end
      end

      attr_reader :template_dir

      def initialize(**kwargs)
        super
        unless (@template_dir = self.class.template_dir)
          raise NotImplementedError, "#{self.class} did not define template_dir"
        end
      end

      def print_action(action, source = nil, dest)
        line = "\t#{colors.bold(colors.green(action))}"
        line << "\t#{colors.green(source)}" if source
        line << "\t#{colors.green(dest)}" if dest
        puts line
      end

      def mkdir(path)
        print_action "mkdir", path
        ::FileUtils.mkdir_p(path)
      end

      def cp(source, dest)
        print_action "cp", source, dest
        ::FileUtils.cp(File.join(@template_dir, source), dest)
      end

      def erb(source, dest = nil)
        print_action("erb", source, dest) if dest
        super(File.join(@template_dir, source), dest)
      end

      def sh(command, *arguments)
        print_action "run", [command, *arguments].join(" ")
        system(command, *arguments)
      end
    end
  end
end
