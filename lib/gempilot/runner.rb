# frozen_string_literal: true

require "pty"
require "fileutils"

module Gempilot
  class Runner
    attr_reader :silent, :command

    def initialize(command, silent: false, debug: ENV.fetch("DEBUG", false))
      @debug = debug
      @command = command
      @silent = silent
      @used_fds = Set.new([0, 1, 2, 3])
      @tee_reader, @tee_writer = IO.pipe
      @ready = true
    end

    def run(input = nil, &)
      validate_ready!
      @ready = false
      start(input, &)
    end

    private

    def start(input, &block)
      wait_threads ||= []
      p command

      if @debug && !File.exist?(".inuse")
        FileUtils.touch ".inuse"
        threads = []
        $stdin.raw do
          PTY.spawn(command) do |reader, writer, pid|
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
      else
        fd = checkout_fd
        sin, sout, wait_threads = Open3.pipeline_rw(
          command,
          "tee /dev/fd/#{fd}",
          fd => @tee_writer
        )

        case [block, input]
        in [true, nil] then yield(sin)
        in [false, String] then sin.write(input)
        in [false, IO] then IO.copy_stream(input, sin)
        in [false, nil] then sin.close
        in [true, Object] if !input.nil?
          raise ArgumentError, "Cannot pass a block with input: #{input.class}"
        else
          raise ArgumentError, "Invalid input type: #{input.class}"
        end

        wait_threads << Thread.new { IO.copy_stream(@tee_reader, $stdout) } unless @silent
        sin.close
        @tee_writer.close

        wait_threads.each(&:join)

        sout.read
      end
    end

    def validate_ready!
      return if @ready

      raise "Cannot proceed, this session has already been activated"
    end

    def checkout_fd
      (10..1023).each do |fd|
        next if @used_fds.include?(fd)

        begin
          IO.for_fd(fd)
        rescue Errno::EBADF
          @used_fds.add(fd)
          return fd
        end
      end
      raise "No available file descriptors"
    end
  end
end
