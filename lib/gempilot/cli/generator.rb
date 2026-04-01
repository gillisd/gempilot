require "bundler"
require "command_kit/colors"
require "command_kit/file_utils"
require "fileutils"
require "erb"

module Gempilot
  class CLI
    ## File generation utilities for scaffolding gems and components.
    module Generator
      include CommandKit::Colors
      include CommandKit::FileUtils

      def self.included(command)
        command.extend ClassMethods
      end

      ## Class-level helpers for Generator, including +template_dir+ resolution.
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

        return if (@template_dir = self.class.template_dir)

        raise NotImplementedError, "#{self.class} did not define template_dir"
      end

      def print_action(command, source = nil, dest)
        line = +""
        line << "\t" << colors.bold(colors.green(command))
        line << "\t" << colors.green(source) if source
        line << "\t" << colors.green(dest) if dest

        puts(line)
      end

      def mkdir(path)
        print_action "mkdir", path
        ::FileUtils.mkdir_p(path)
      end

      def touch(path)
        print_action "touch", path
        ::FileUtils.touch(path)
      end

      def create_file(path, content)
        print_action "create", path
        File.write(path, content)
      end

      def chmod(mode, path)
        print_action "chmod", path
        ::FileUtils.chmod(mode, path)
      end

      def cp(source, dest)
        print_action "cp", source, dest
        ::FileUtils.cp(File.join(@template_dir, source), dest)
      end

      def erb(source, dest = nil)
        print_action "erb", source, dest if dest

        source_path = File.join(@template_dir, source)
        super(source_path, dest)
      end

      def sh(command, *arguments)
        print_action "run", [command, *arguments].join(" ")
        success = Bundler.with_unbundled_env do
          system(command, *arguments)
        end
        puts colors.yellow("Warning: '#{[command, *arguments].join(" ")}' exited with non-zero status") unless success
        success
      end
    end
  end
end
