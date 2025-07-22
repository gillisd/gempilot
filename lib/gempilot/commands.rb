# frozen_string_literal: true

require "shellwords"

module Gempilot
  module Commands
    def bundle_add(*gems)
      # Bundler::CLI::Add.new({ force: true }, gems).run
      # bundle 'add', *gems, force: true
    end

    def bundle_config_set(setting, value)
      # Bundler::CLI::Config.new.invoke(:set, [setting, value])
      # bundle 'config', 'set', setting, value
    end

    def bundle_config_unset(setting)
      bundle "config", "unset", setting
    end

    def bundle(*args, **options)
      command = ["bin/bundle"]
      command.concat(args.map(&:to_s))
      options = options.each_with_object(StringIO.new) do |(k, v), io|
        case v
        when TrueClass, FalseClass
          io << "--#{k}" if v
        when String, Symbol
          io << "--#{k} #{v.shellescape}"
        when Array
          v.each { |item| io << "--#{k} #{item.shellescape} " }
        end
      end
      command.concat(options.string.shellsplit)

      sh command.shelljoin
    end

    def bundle_init
      command = ["bin/bundle", "init"]
      sh command.shelljoin
    end

    def bundle_binstub(*gems)
      command = []
      command.push("bin/bundle", "binstub", "--force")
      command.concat(gems.map(&:to_s))
      sh command.shelljoin
    end

    def sh(command, silent: false, input: nil, &)
      runner = Gempilot::Runner.new(command, silent: silent)
      begin
        runner.run(input, &)
      rescue Errno::ENOENT
        raise Gempilot::CommandError,
              "Command not found: #{command}. Ensure it is installed and available in your PATH."
      end
    end
  end
end
