module Gempilot
  class Buffer
    def initialize(string = '')
      @io = StringIO.new(string.dup)
    end

    def grep_v(...)
      rewind
      @io.grep_v(...)
    end

    def each(...)
      rewind
      @io.each(...)
    end

    def rewind
      @io.rewind
    end

    def puts(...)
      @io.pos = @io.size
      begin
        @io.puts(...)
      rescue => e
        raise e
      end
    end

    def write_position=(lineno)
      @io.lineno = lineno
    end

    def copy_to(io)
      rewind
      @io
        .read
        .then { io.write(_1) }
        .tap { rewind }
    end

    def gsub!(...)
      @io
        .tap(&:rewind)
        .read
        .then { _1.gsub(...) }
        .tap { @io = StringIO.new(_1) }

      self
    end

    def gets
      @io.gets
    end

    def read
      rewind
      @io.read
    end

    def write(...)
      @io.write(...)
    end
  end
end
