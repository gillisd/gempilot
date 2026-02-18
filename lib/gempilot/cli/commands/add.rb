require_relative "../command"
require_relative "../generator"
require "command_kit/inflector"

module Gempilot
  class CLI
    module Commands
      class Add < Command
        include Generator

        template_dir File.join(Gempilot::ROOT, "data", "templates", "add")

        usage "[options] TYPE PATH"
        description "Add a class, module, or command to an existing gem"

        examples [
          "class authentication",
          "class services/authentication",
          "module middleware",
          "command deploy"
        ]

        argument :type, required: false,
                        desc: "Type to generate (class, module, command)"

        argument :path, required: false,
                        desc: "Path relative to gem namespace (e.g., services/authentication)"

        def run(type = nil, path = nil)
          type = type || begin
            puts colors.bright_black("What kind of component do you want to add?")
            ask_multiple_choice(colors.green("Type"), %w[class module command])
          end

          path = path || begin
            puts
            puts colors.bright_black("Path relative to the gem namespace (e.g., services/authentication).")
            ask(colors.green("Path"), required: true)
          end

          detect_gem_context

          case type
          when "class"   then add_class(path)
          when "module"  then add_module(path)
          when "command" then add_command(path)
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

        def build_nested_source(namespaces, type_keyword, name)
          lines = []
          namespaces.each_with_index do |ns, i|
            lines << "#{"  " * i}module #{ns}"
          end

          depth = namespaces.length
          lines << "#{"  " * depth}#{type_keyword} #{name}"
          lines << "#{"  " * depth}end"

          namespaces.length.times do |i|
            lines << "#{"  " * (namespaces.length - 1 - i)}end"
          end

          lines.join("\n") + "\n"
        end

        def parse_path(path)
          segments = path.tr("-", "_").split("/")
          modules = segments[0...-1].map { |s| CommandKit::Inflector.camelize(s) }
          name = CommandKit::Inflector.camelize(segments.last)
          [segments, modules, name]
        end

        def add_class(path)
          segments, intermediate_modules, class_name = parse_path(path)
          namespaces = [@gem_module] + intermediate_modules
          file_path = File.join("lib", @gem_name, *segments) + ".rb"

          puts
          puts colors.bright_white("Adding class ") + colors.bold(colors.cyan("#{namespaces.join('::')}::#{class_name}")) + colors.bright_white("...")
          puts

          dir = File.dirname(file_path)
          mkdir(dir) unless File.directory?(dir)

          source = "# frozen_string_literal: true\n\n" + build_nested_source(namespaces, "class", class_name)
          create_file(file_path, source)

          add_test_file(namespaces, class_name, segments)
        end

        def add_module(path)
          segments, intermediate_modules, mod_name = parse_path(path)
          namespaces = [@gem_module] + intermediate_modules
          file_path = File.join("lib", @gem_name, *segments) + ".rb"

          puts
          puts colors.bright_white("Adding module ") + colors.bold(colors.cyan("#{namespaces.join('::')}::#{mod_name}")) + colors.bright_white("...")
          puts

          dir = File.dirname(file_path)
          mkdir(dir) unless File.directory?(dir)

          source = "# frozen_string_literal: true\n\n" + build_nested_source(namespaces, "module", mod_name)
          create_file(file_path, source)
        end

        def add_command(path)
          segments, _, command_name = parse_path(path)
          file_path = File.join("lib", @gem_name, "cli", "commands", segments.last + ".rb")

          puts
          puts colors.bright_white("Adding command ") + colors.bold(colors.cyan(command_name)) + colors.bright_white("...")
          puts

          dir = File.dirname(file_path)
          mkdir(dir) unless File.directory?(dir)

          @command_name = command_name
          @command_file_name = segments.last
          erb "command.rb.erb", file_path
        end

        def add_test_file(namespaces, class_name, segments)
          if @test_framework == :rspec
            test_path = File.join("spec", @gem_name, *segments) + "_spec.rb"
            test_dir = File.dirname(test_path)
            mkdir(test_dir) unless File.directory?(test_dir)

            content = <<~RUBY
              # frozen_string_literal: true

              require "spec_helper"

              RSpec.describe #{namespaces.join('::')}::#{class_name} do
                pending "add some examples"
              end
            RUBY
            create_file(test_path, content)
          else
            test_path = File.join("test", @gem_name, *segments) + "_test.rb"
            test_dir = File.dirname(test_path)
            mkdir(test_dir) unless File.directory?(test_dir)

            content = <<~RUBY
              # frozen_string_literal: true

              require "test_helper"

              module #{namespaces.first}
                class #{(namespaces[1..] + [class_name]).join('::')}Test < Minitest::Test
                  def test_placeholder
                    assert true
                  end
                end
              end
            RUBY
            create_file(test_path, content)
          end
        end
      end
    end
  end
end
