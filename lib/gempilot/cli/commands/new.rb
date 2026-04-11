module Gempilot
  class CLI
    module Commands
      ## Generates a new class, module, or command inside an existing gem.
      class New < Command
        using String::Inflectable

        include Generator
        include GemContext

        template_dir File.join(Gempilot::ROOT, "data", "templates", "new")

        usage "[options] TYPE CONSTANT"
        description "Generate a class, module, or command in an existing gem"

        examples [
          "class MyGem::Authentication",
          "class MyGem::Services::Authentication",
          "module MyGem::Middleware",
          "command deploy",
        ]

        argument :type, required: false,
                        desc: "Type to generate (class, module, command)"

        argument :path, required: false,
                        desc: "Fully-qualified constant (e.g., MyGem::Services::Auth) or command name"

        def run(type = nil, path = nil)
          type ||= prompt_for_type
          detect_gem_context
          path ||= prompt_for_path
          dispatch_add(type, path)
        end

        private

        def prompt_for_type
          puts colors.bright_black("What kind of component do you want to add?")
          ask_multiple_choice(colors.green("Type"), %w[class module command])
        end

        def prompt_for_path
          puts
          puts colors.bright_black("Fully-qualified constant name (e.g., #{@gem_module}::Services::Authentication).")
          ask(colors.green("Constant"), required: true)
        end

        def dispatch_add(type, path)
          case type
          when "class"   then add_class(path)
          when "module"  then add_module(path)
          when "command" then add_command(path)
          else
            puts colors.red("Unknown type '#{type}'. Use class, module, or command.")
            exit 1
          end
        end

        def build_namespace_lines(namespaces)
          namespaces.each_with_index.map do |ns, i|
            "#{"  " * i}module #{ns}"
          end
        end

        def build_closing_lines(namespaces)
          Array.new(namespaces.length) do |i|
            "#{"  " * (namespaces.length - 1 - i)}end"
          end
        end

        def build_nested_source(namespaces, type_keyword, name)
          depth = namespaces.length
          lines = build_namespace_lines(namespaces)
          lines << "#{"  " * depth}#{type_keyword} #{name}"
          lines << "#{"  " * depth}end"
          lines.concat(build_closing_lines(namespaces))
          "#{lines.join("\n")}\n"
        end

        def print_adding_banner(kind, label)
          puts
          puts colors.bright_white("Adding #{kind} ") +
               colors.bold(colors.cyan(label)) +
               colors.bright_white("...")
          puts
        end

        def prepare_constant(constant)
          namespaces, name, segments = parse_constant(constant)
          validate_gem_root!(namespaces.first)
          file_path = "#{File.join("lib", *segments)}.rb"
          ensure_directory(File.dirname(file_path))
          [namespaces, name, segments, file_path]
        end

        def ensure_directory(dir)
          mkdir(dir) unless File.directory?(dir)
        end

        def add_class(constant)
          namespaces, class_name, segments, file_path = prepare_constant(constant)
          print_adding_banner("class", "#{namespaces.join("::")}::#{class_name}")
          source = build_nested_source(namespaces, "class", class_name)
          create_file(file_path, source)
          add_test_file(namespaces, class_name, segments)
        end

        def add_module(constant)
          namespaces, mod_name, _segments, file_path = prepare_constant(constant)
          print_adding_banner("module", "#{namespaces.join("::")}::#{mod_name}")
          source = build_nested_source(namespaces, "module", mod_name)
          create_file(file_path, source)
        end

        def add_command(name)
          file_name = name.underscore
          command_name = name.camelize
          file_path = File.join("lib", @require_path, "cli", "commands", "#{file_name}.rb")

          print_adding_banner("command", command_name)
          ensure_directory(File.dirname(file_path))

          @command_name = command_name
          @command_file_name = file_name
          erb "command.rb.erb", file_path
          add_command_test_file(command_name, file_name)
        end

        def command_test_path(file_name)
          if @test_framework == :rspec
            File.join("spec", @require_path, "cli", "commands", "#{file_name}_spec.rb")
          else
            File.join("test", @require_path, "cli", "commands", "#{file_name}_test.rb")
          end
        end

        def rspec_command_content(command_name)
          <<~RUBY
            require "spec_helper"

            RSpec.describe #{@gem_module}::CLI::Commands::#{command_name} do
              it "is defined" do
                expect(described_class).not_to be_nil
              end
            end
          RUBY
        end

        def minitest_command_content(command_name)
          <<~RUBY
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
        end

        def add_command_test_file(command_name, file_name)
          test_path = command_test_path(file_name)
          ensure_directory(File.dirname(test_path))
          content = if @test_framework == :rspec
                      rspec_command_content(command_name)
                    else
                      minitest_command_content(command_name)
                    end
          create_file(test_path, content)
        end

        def class_test_path(segments)
          if @test_framework == :rspec
            "#{File.join("spec", @require_path, *segments[1..])}_spec.rb"
          else
            "#{File.join("test", @require_path, *segments[1..])}_test.rb"
          end
        end

        def rspec_class_content(namespaces, class_name)
          <<~RUBY
            require "spec_helper"

            RSpec.describe #{namespaces.join("::")}::#{class_name} do
              pending "add some examples"
            end
          RUBY
        end

        def minitest_class_content(namespaces, class_name)
          <<~RUBY
            require "test_helper"

            module #{namespaces.first}
              class #{(namespaces[1..] + [class_name]).join("::")}Test < Minitest::Test
                def test_placeholder
                  assert true
                end
              end
            end
          RUBY
        end

        def add_test_file(namespaces, class_name, segments)
          test_path = class_test_path(segments)
          ensure_directory(File.dirname(test_path))
          content = if @test_framework == :rspec
                      rspec_class_content(namespaces, class_name)
                    else
                      minitest_class_content(namespaces, class_name)
                    end
          create_file(test_path, content)
        end
      end
    end
  end
end
