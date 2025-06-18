require 'pty'
require 'warning'
require 'fileutils'
require 'io/console'
module Gempilot
  class Runner
    attr_reader :silent, :command

    def initialize(command, silent: false, debug: ENV.fetch('DEBUG', false))
      @debug = debug
      @command = command
      @silent = silent
      @used_fds = Set.new([0, 1, 2, 3])
      @tee_reader, @tee_writer = IO.pipe
      @ready = true
    end

    def run(input = nil, &block)
      validate_ready!
      @ready = false
      start(input, &block)
    end

    private

    def debug
      puts "COMMAND: [#{RUBY} #{option_list.join ' '}]" if @verbose

      threads = []
      $stdin.raw do
        master, slave = PTY.open

        threads << Thread.new do
          IO.copy_stream reader, $stdout
        end

        threads << Thread.new do
          IO.copy_stream $stdin, writer
        end

        @exit = Process.wait(pid)
        threads.each { |thread| Thread.kill(thread) }

        # @out = out.read
        # @err = err.read
      end

      puts "OUTPUT:  [#{@out}]" if @verbose
      puts "ERROR:   [#{@err}]" if @verbose
      puts "EXIT:    [#{@exit.inspect}]" if @verbose
      puts "PWD:     [#{Dir.pwd}]" if @verbose
    end

    def start(input, &block)
      wait_threads ||= []
      p command

      # wait_threads << wait_thread
      if @debug && !File.exist?('.inuse')
        FileUtils.touch '.inuse'
        threads = []
        $stdin.raw do
          PTY.spawn(command) do |reader, writer, pid|
            # sin, sout, wait_thread = Open3.popen_run(command)
            threads << Thread.new do
              IO.copy_stream reader, $stdout
            end

            threads << Thread.new do
              IO.copy_stream $stdin, writer
            end

            @exit = Process.wait(pid)
            threads.each { |thread| Thread.kill(thread) }
          end
        end

        # $stdin.raw do
        #   master, slave = PTY.open
        #   begin
        #     wait_threads << Thread.new do
        #       IO.copy_stream sout, slave
        #     end
        #
        #     wait_threads << Thread.new do
        #       IO.copy_stream slave, sin
        #     end
        #
        #     wait_threads << Thread.new do
        #       IO.copy_stream master, $stdout
        #     end
        #
        #     wait_threads << Thread.new do
        #       IO.copy_stream $stdin, master
        #     end
        #   rescue => e
        #     exit 1
        #
        #     wait_threads.each { |thread| Thread.kill(thread) }
        #
        #     sin.close
        #     sout.close
        #     master.close
        #     slave.close
        #   ensure
        #     p 'waiting'
        #     wait_threads.each(&:join)
        #     p 'here'
        #     # sin.close
        #     # sout.close
        #     # master.close
        #     # slave.close
        #     # end
        #   end
        # end

      else
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