require_relative "../command"
require "command_kit/inflector"
require "fileutils"

module Gempilot
  class CLI
    module Commands
      class Destroy < Command
        usage "[options] TYPE CONSTANT"
        description "Remove a class, module, or command from an existing gem"

        examples [
          "class MyGem::Services::Authentication",
          "module MyGem::Middleware",
          "command deploy"
        ]

        argument :type, required: false,
                        desc: "Type to destroy (class, module, command)"

        argument :path, required: false,
                        desc: "Fully-qualified constant (e.g., MyGem::Services::Auth) or command name"

        def run(type = nil, path = nil)
          type = type || begin
            puts colors.bright_black("What kind of component do you want to destroy?")
            ask_multiple_choice(colors.green("Type"), %w[class module command])
          end

          detect_gem_context

          path = path || begin
            puts
            puts colors.bright_black("Fully-qualified constant name (e.g., #{@gem_module}::Services::Authentication).")
            ask(colors.green("Constant"), required: true)
          end

          case type
          when "class"   then destroy_class(path)
          when "module"  then destroy_module(path)
          when "command" then destroy_command(path)
          else
            puts colors.red("Unknown type '#{type}'. Use class, module, or command.")
            exit 1
          end
        end

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

        def destroy_class(constant)
          namespaces, _class_name, segments = parse_constant(constant)
          validate_gem_root!(namespaces.first)

          lib_path = File.join("lib", *segments) + ".rb"

          if @test_framework == :rspec
            test_path = File.join("spec", @gem_name, *segments[1..]) + "_spec.rb"
          else
            test_path = File.join("test", @gem_name, *segments[1..]) + "_test.rb"
          end

          remove_file(lib_path)
          remove_file(test_path)
          remove_empty_parents(File.dirname(lib_path), File.join("lib", @gem_name))
          test_root = @test_framework == :rspec ? File.join("spec", @gem_name) : File.join("test", @gem_name)
          remove_empty_parents(File.dirname(test_path), test_root)
        end

        def destroy_module(constant)
          namespaces, _mod_name, segments = parse_constant(constant)
          validate_gem_root!(namespaces.first)

          lib_path = File.join("lib", *segments) + ".rb"
          remove_file(lib_path)
          remove_empty_parents(File.dirname(lib_path), File.join("lib", @gem_name))
        end

        def destroy_command(name)
          file_name = CommandKit::Inflector.underscore(name)
          file_path = File.join("lib", @gem_name, "cli", "commands", file_name + ".rb")
          remove_file(file_path)
        end

        def remove_file(path)
          if File.exist?(path)
            print_remove(path)
            ::FileUtils.rm(path)
          else
            print_skip(path)
          end
        end

        def remove_empty_parents(dir, stop_at)
          while dir != stop_at && dir.start_with?(stop_at)
            break unless File.directory?(dir)
            break unless Dir.empty?(dir)

            print_remove(dir)
            ::FileUtils.rmdir(dir)
            dir = File.dirname(dir)
          end
        end

        def print_remove(path)
          puts "\t#{colors.bold(colors.red('remove'))}\t#{colors.red(path)}"
        end

        def print_skip(path)
          puts "\t#{colors.bold(colors.yellow('skip'))}\t#{colors.yellow(path)}"
        end
      end
    end
  end
end
