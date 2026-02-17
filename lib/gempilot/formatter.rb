
module Gempilot
  class Formatter
    def initialize(formatter: RuboCop::CLI.new)
      @formatter = formatter
    end

    def format(path)
      result = run(path, autocorrect: true, safe_autocorrect: true)
      if result == :success
        puts "Formatted #{path} successfully"
        return
      end

      warn "Failed to format #{path} with code: #{result}"
      raise RuboCop::Error, "Failed to format #{path} with code: #{result}"
    end

    def dry_run(path)
      run(path, autocorrect: false, safe_autocorrect: false)
    end

    private

    def run(path, autocorrect: false, safe_autocorrect: false)
      path = Pathname.new(path)
      raise "Path #{path} does not exist" unless path.exist?

      path = path.expand_path

      args = [].tap do |a|
        a << "--autocorrect" if autocorrect
        a << "--safe-auto-correct" if safe_autocorrect
        a << path.to_path
      end

      code = @formatter.run(args)

      case code.to_i
      in 0 then :success
      in 1 then :failure_code_1
      in 2 then :failure_code_2
      else
        raise "Unknown error code: #{code}"
      end
    end
  end
end
