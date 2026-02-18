require_relative "../command"
require_relative "../generator"
require_relative "../gem_context"
require "command_kit/inflector"

module Gempilot
  class CLI
    module Commands
      class New < Command
        include Generator
        include GemContext

        template_dir File.join(Gempilot::ROOT, "data", "templates", "new")

        usage "[options] TYPE CONSTANT"
        description "Generate a class, module, or command in an existing gem"

        examples [
          "class MyGem::Authentication",
          "class MyGem::Services::Authentication",
          "module MyGem::Middleware",
          "command deploy"
        ]

        argument :type, required: false,
                        desc: "Type to generate (class, module, command)"

        argument :path, required: false,
                        desc: "Fully-qualified constant (e.g., MyGem::Services::Auth) or command name"

        def run(type = nil, path = nil)
          type = type || begin
            puts colors.bright_black("What kind of component do you want to add?")
            ask_multiple_choice(colors.green("Type"), %w[class module command])
          end

          detect_gem_context

          path = path || begin
            puts
            puts colors.bright_black("Fully-qualified constant name (e.g., #{@gem_module}::Services::Authentication).")
            ask(colors.green("Constant"), required: true)
          end

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

        def add_class(constant)
          namespaces, class_name, segments = parse_constant(constant)
          validate_gem_root!(namespaces.first)
          file_path = File.join("lib", *segments) + ".rb"

          puts
          puts colors.bright_white("Adding class ") + colors.bold(colors.cyan("#{namespaces.join('::')}::#{class_name}")) + colors.bright_white("...")
          puts

          dir = File.dirname(file_path)
          mkdir(dir) unless File.directory?(dir)

          source = build_nested_source(namespaces, "class", class_name)
          create_file(file_path, source)

          add_test_file(namespaces, class_name, segments)
        end

        def add_module(constant)
          namespaces, mod_name, segments = parse_constant(constant)
          validate_gem_root!(namespaces.first)
          file_path = File.join("lib", *segments) + ".rb"

          puts
          puts colors.bright_white("Adding module ") + colors.bold(colors.cyan("#{namespaces.join('::')}::#{mod_name}")) + colors.bright_white("...")
          puts

          dir = File.dirname(file_path)
          mkdir(dir) unless File.directory?(dir)

          source = build_nested_source(namespaces, "module", mod_name)
          create_file(file_path, source)
        end

        def add_command(name)
          file_name = CommandKit::Inflector.underscore(name)
          command_name = CommandKit::Inflector.camelize(name)
          file_path = File.join("lib", @require_path, "cli", "commands", file_name + ".rb")

          puts
          puts colors.bright_white("Adding command ") + colors.bold(colors.cyan(command_name)) + colors.bright_white("...")
          puts

          dir = File.dirname(file_path)
          mkdir(dir) unless File.directory?(dir)

          @command_name = command_name
          @command_file_name = file_name
          erb "command.rb.erb", file_path

          add_command_test_file(command_name, file_name)
        end

        def add_command_test_file(command_name, file_name)
          if @test_framework == :rspec
            test_path = File.join("spec", @require_path, "cli", "commands", "#{file_name}_spec.rb")
            test_dir = File.dirname(test_path)
            mkdir(test_dir) unless File.directory?(test_dir)

            content = <<~RUBY
              require "spec_helper"

              RSpec.describe #{@gem_module}::CLI::Commands::#{command_name} do
                it "is defined" do
                  expect(described_class).not_to be_nil
                end
              end
            RUBY
            create_file(test_path, content)
          else
            test_path = File.join("test", @require_path, "cli", "commands", "#{file_name}_test.rb")
            test_dir = File.dirname(test_path)
            mkdir(test_dir) unless File.directory?(test_dir)

            content = <<~RUBY
              require "test_helper"
              require "#{@require_path}/cli"
              require "stringio"

              module #{@gem_module}
                class CLI
                  class #{command_name}Test < Minitest::Test
                    def test_placeholder
                      stdout = StringIO.new
                      command = Commands::#{command_name}.new(stdout: stdout)
                      assert command
                    end
                  end
                end
              end
            RUBY
            create_file(test_path, content)
          end
        end

        def add_test_file(namespaces, class_name, segments)
          if @test_framework == :rspec
            test_path = File.join("spec", @require_path, *segments[1..]) + "_spec.rb"
            test_dir = File.dirname(test_path)
            mkdir(test_dir) unless File.directory?(test_dir)

            content = <<~RUBY
              require "spec_helper"

              RSpec.describe #{namespaces.join('::')}::#{class_name} do
                pending "add some examples"
              end
            RUBY
            create_file(test_path, content)
          else
            test_path = File.join("test", @require_path, *segments[1..]) + "_test.rb"
            test_dir = File.dirname(test_path)
            mkdir(test_dir) unless File.directory?(test_dir)

            content = <<~RUBY
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
