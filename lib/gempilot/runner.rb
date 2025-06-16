module Gempilot
  class Runner
    attr_reader :silent, :command

    def initialize(command, silent: false)
      @command = command
      @silent = silent
      @used_fds = Set.new([0, 1, 2, 3])
      @tee_reader, @tee_writer = IO.pipe
      @ready = true
    end

    def run(input, &block)
      validate_ready!
      @ready = false
      start(input, &block)
    end

    private

    def start(input, &block)
      fd = checkout_fd
      sin, sout, wait_threads = Open3.pipeline_rw(
        command,
        "tee /dev/fd/#{fd}",
        fd => @tee_writer
      )

      case [block_given?, input]
      in [true, nil] then block.call(sin)
      in [false, String] then sin.write(input)
      in [false, IO] then IO.copy_stream(input, sin)
      in [false, nil] then sin.close
      in [true, Object] if !input.nil? then
        raise ArgumentError, "Cannot pass a block with input: #{input.class}"
      else
        raise ArgumentError, "Invalid input type: #{input.class}"
      end

      # Use @silent consistently
      wait_threads << Thread.new { IO.copy_stream(@tee_reader, $stdout) } unless @silent
      sin.close
      @tee_writer.close

      wait_threads.each(&:join)

      sout.read
    end

    def validate_ready!
      return if @ready

      raise 'Cannot proceed, this session has already been activated'
    end

    def checkout_fd
      (10..1023).each do |fd|
        next if @used_fds.include?(fd)
        begin
          IO.for_fd(fd) # Test if FD exists
          # If we get here, FD is in use, continue loop
        rescue Errno::EBADF
          # FD is available
          @used_fds.add(fd)
          return fd
        end
      end
      raise "No available file descriptors"
    end
  end
end