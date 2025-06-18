require 'shellwords'

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
      bundle 'config', 'unset', setting
    end

    def bundle(*args, **options)
      command = %w[bin/bundle]
      command.concat(args.map(&:to_s))
      options = options.inject(StringIO.new) do |io, (k, v)|
        if v.is_a?(TrueClass) || v.is_a?(FalseClass)
          io << "--#{k}" if v
        elsif v.is_a?(String) || v.is_a?(Symbol)
          io << "--#{k} #{v.shellescape}"
        elsif v.is_a?(Array)
          v.each { |item| io << "--#{k} #{item.shellescape} " }
        end
        io
      end
      command.concat(options.string.shellsplit)

      sh command.shelljoin
    end

    def bundle_init
      command = %w[bin/bundle init]
      sh command.shelljoin
    end

    def bundle_binstub(*gems)
      command = []
      command.concat %w[bin/bundle binstub --force]
      command.concat(gems.map(&:to_s))
      sh command.shelljoin
    end

    def sh(command, silent: false, input: nil, &block)
      runner = Gempilot::Runner.new(command, silent: silent)
      begin
        runner.run(input, &block)
      rescue Errno::ENOENT => e
        raise Gempilot::CommandError, "Command not found: #{command}. Ensure it is installed and available in your PATH."
      end
    end
  end
end