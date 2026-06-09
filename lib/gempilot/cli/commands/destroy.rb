require "fileutils"

module Gempilot
  class CLI
    module Commands
      ## Removes a class, module, or command from an existing gem.
      class Destroy < Command
        using String::Inflectable

        include GemContext

        usage "[options] TYPE CONSTANT"
        description "Remove a class, module, or command from an existing gem"

        examples [
          "class MyGem::Services::Authentication",
          "module MyGem::Middleware",
          "command deploy",
        ]

        argument :type, required: false,
                        desc: "Type to destroy (class, module, command)"

        argument :path, required: false,
                        desc: "Fully-qualified constant (e.g., MyGem::Services::Auth) or command name"

        def run(type = nil, path = nil)
          type ||= prompt_for_type
          detect_gem_context
          path ||= prompt_for_path(type)
          dispatch_destroy(type, path)
        end

        private

        def prompt_for_type
          puts colors.bright_black("What kind of component do you want to destroy?")
          ask_multiple_choice(colors.green("Type"), %w[class module command])
        end

        def prompt_for_path(type)
          name = ask(colors.green(type), required: true)
          return name if type == "command"

          # Class/module constants belong under the gem's module, so prepend it
          # to save the user retyping it, unless the input is already rooted
          # there (matched on the root segment, as validate_gem_root! does).
          root = @gem_module.split("::").first
          name.start_with?("#{root}::") ? name : "#{@gem_module}::#{name}"
        end

        def dispatch_destroy(type, path)
          case type
          when "class"   then destroy_class(path)
          when "module"  then destroy_module(path)
          when "command" then destroy_command(path)
          else
            puts colors.red("Unknown type '#{type}'. Use class, module, or command.")
            exit 1
          end
        end

        def destroy_class(constant)
          namespaces, _class_name, segments = parse_constant(constant)
          validate_gem_root!(namespaces.first)

          lib_path = "#{File.join("lib", *segments)}.rb"
          test_path = test_path_for(segments)

          remove_file(lib_path)
          remove_file(test_path)
          cleanup_empty_dirs(lib_path, test_path)
        end

        def test_path_for(segments)
          # @require_path already covers the gem module's segments, so drop them
          # all (not just one) to stay correct for hyphenated, multi-segment gems.
          rest = segments.drop(@require_path.split("/").length)
          if @test_framework == :rspec
            "#{File.join("spec", @require_path, *rest)}_spec.rb"
          else
            "#{File.join("test", @require_path, *rest)}_test.rb"
          end
        end

        def cleanup_empty_dirs(lib_path, test_path)
          remove_empty_parents(File.dirname(lib_path), File.join("lib", @require_path))
          test_root = @test_framework == :rspec ? File.join("spec", @require_path) : File.join("test", @require_path)
          remove_empty_parents(File.dirname(test_path), test_root)
        end

        def destroy_module(constant)
          namespaces, _mod_name, segments = parse_constant(constant)
          validate_gem_root!(namespaces.first)

          lib_path = "#{File.join("lib", *segments)}.rb"
          remove_file(lib_path)
          remove_empty_parents(File.dirname(lib_path), File.join("lib", @require_path))
        end

        def destroy_command(name)
          name = name.split("::").last if name.include?("::")
          file_name = name.underscore
          file_path = File.join("lib", @require_path, "cli", "commands", "#{file_name}.rb")
          remove_file(file_path)

          test_path = if @test_framework == :rspec
                        File.join("spec", @require_path, "cli", "commands", "#{file_name}_spec.rb")
                      else
                        File.join("test", @require_path, "cli", "commands", "#{file_name}_test.rb")
                      end
          remove_file(test_path)
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
          puts "\t#{colors.bold(colors.red("remove"))}\t#{colors.red(path)}"
        end

        def print_skip(path)
          puts "\t#{colors.bold(colors.yellow("skip"))}\t#{colors.yellow(path)}"
        end
      end
    end
  end
end
