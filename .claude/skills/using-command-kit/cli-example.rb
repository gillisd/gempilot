# Complete CommandKit CLI example following Ronin patterns
#
# Entry point (exe/mytool):
#   #!/usr/bin/env ruby
#   ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
#   require "bundler/setup"
#   require "mytool/cli"
#   MyTool::CLI.start

# lib/mytool/cli.rb
require "command_kit/commands"
require "command_kit/commands/auto_load"
require "command_kit/options/version"

module MyTool
  class CLI
    include CommandKit::Commands
    include CommandKit::Commands::AutoLoad.new(
      dir:       "#{__dir__}/cli/commands",
      namespace: "#{self}::Commands"
    )
    include CommandKit::Options::Version

    command_name "mytool"
    version MyTool::VERSION

    command_aliases["g"] = "generate"
  end
end

# lib/mytool/cli/command.rb
module MyTool
  class CLI
    class Command < CommandKit::Command
      include CommandKit::Colors
      include CommandKit::Interactive

      bug_report_url "https://github.com/user/mytool/issues/new"
    end
  end
end

# lib/mytool/cli/commands/generate.rb
module MyTool
  class CLI
    module Commands
      class Generate < Command
        include Generator

        template_dir File.join(ROOT, "data", "templates", "component")

        usage "[options] NAME"
        description "Generate a new component"

        examples [
          "my_widget",
          "--test rspec my_widget",
          "--no-git my_widget"
        ]

        option :test, value: {
          type: { "minitest" => :minitest, "rspec" => :rspec },
          default: :minitest
        }, desc: "Test framework"

        option :git, desc: "Initialize git repo"

        argument :name, required: true, desc: "Component name"

        # Prompt for missing args via CommandKit::Interactive
        def run(name = nil)
          @name = name || ask("Component name:", required: true)
          @module_name = CommandKit::Inflector.camelize(@name)
          @test = options[:test] || ask_multiple_choice("Test framework:", %w[minitest rspec])
          @git = options.fetch(:git) { ask_yes_or_no("Initialize git?", default: true) }

          mkdir @name
          erb "main.rb.erb", "#{@name}/lib/#{@name}.rb"
          erb "version.rb.erb", "#{@name}/lib/#{@name}/version.rb"
        end
      end
    end
  end
end
