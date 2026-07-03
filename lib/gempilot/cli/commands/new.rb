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
          path ||= prompt_for_path(type)
          dispatch_add(type, path)
        end

        private

        def prompt_for_type
          puts colors.bright_black("What kind of component do you want to add?")
          ask_multiple_choice(colors.green("Type"), %w[class module command])
        end

        def prompt_for_path(type)
          ask(colors.green(type), required: true)
        end

        def dispatch_add(type, path)
          case type
          when "class"   then add_class(gem_constant(path))
          when "module"  then add_module(gem_constant(path))
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
          styled_label = colors.bold(colors.cyan(label))
          puts
          puts colors.bright_white("Adding #{kind} ") + styled_label + colors.bright_white("...")
          puts
        end

        def ensure_directory(dir)
          mkdir(dir) unless File.directory?(dir)
        end

        def add_class(constant)
          print_adding_banner("class", constant.qualified)
          ensure_directory(File.dirname(constant.lib_path))
          source = build_nested_source(constant.namespaces, "class", constant.name)
          create_file(constant.lib_path, source)
          add_test_file(constant)
        end

        def add_module(constant)
          print_adding_banner("module", constant.qualified)
          ensure_directory(File.dirname(constant.lib_path))
          source = build_nested_source(constant.namespaces, "module", constant.name)
          create_file(constant.lib_path, source)
        end

        def add_command(name)
          name = name.split("::").last if name.include?("::")
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

        def add_test_file(constant)
          test_path = constant.test_path(@test_framework)
          ensure_directory(File.dirname(test_path))
          content = if @test_framework == :rspec
                      rspec_class_content(constant.namespaces, constant.name)
                    else
                      minitest_class_content(constant.namespaces, constant.name)
                    end
          create_file(test_path, content)
        end
      end
    end
  end
end
