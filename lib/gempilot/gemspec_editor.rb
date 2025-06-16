module Gempilot
  class GemspecEditor
    include FileUtils

    attr_reader :working_buffer

    def initialize(gemspec_path, &block)
      @gemspec_path = Pathname.new(gemspec_path)
      @spec = nil
      @readonly_buffer = nil
      @working_buffer = Buffer.new

      raise 'Block is required to initialize GemSpecEditor' unless block

      clean_slate
      block.call(self)
      import_dev_dependencies
      save
      chdir @gemspec_path.parent do
        system 'bundle install', out: $stdout, err: $stderr
      end
      @clean_gemfile.call
      publish
      format
    end

    def import_dev_dependencies
      gemfile_path = @gemspec_path.parent.join('Gemfile')
      to_write = nil
      if gemfile_path.exist?
        gemfile_path.open do |f|
          dev_dependencies = f.read.scan(/gem\s+['"]([^'"]+)['"]\s*,\s*['"]([^'"]+)['"]/)
          dev_dependencies.each do |name, version|
            add_dev_dependency(name, version)
          end
          f.rewind
          to_write = f.grep_v(/gem\s+['"]([^'"]+)['"],?/)
        end
        @clean_gemfile = lambda do
          gemfile_path.open('w') do |f|
            to_write
              .map(&:strip)
              .reject(&:empty?)
              .then { remove_comments _1 }
              .each { |line| f.puts line }
            f.puts "gem 'rubocop', require: false"
            f.puts "gem 'rake', require: false"
            f.puts "gem 'minitest', require: false"
          end
        end
      else
        puts "Gemfile not found at #{gemfile_path}"
      end
    end

    def save
      buf = @working_buffer
              .then { remove_todo _1 }
              .then { remove_comments _1 }
              .then { add_frozen_string_literal _1 }
              .then { squish_blank_lines(_1) }
              .then { remove_ending_blank_lines(_1) }
              .tap { _1.puts "\nend" }

      wip_gemspec_path.open('w') do |spec|
        spec.write(buf.read)
      end
    end

    def publish
      cp @gemspec_path, @gemspec_path.sub_ext('.bak.spec')
      rm_f(@gemspec_path)
      mv wip_gemspec_path, @gemspec_path
      @readonly_buffer = nil
    end

    def formatter
      @formatter ||= Formatter.new
    end

    def format
      puts 'Formatting gemspec'
      chdir @gemspec_path.parent do
        begin
          formatter.format(@gemspec_path)
        rescue RuboCop::Error => e
          puts "Failed to format gemspec: #{e.message}"
          exit 1
        end
        puts 'Formatted gemspec successfully'
      end
    end

    def clean_slate
      raise "Gemspec file not found at #{@gemspec_path}" unless @gemspec_path.exist?

      @gemspec_path
        .read
        .then { Buffer.new(_1) }
        .tap { (@readonly_buffer = Buffer.new(_1.read)).freeze }
        .tap { @working_buffer = Buffer.new(_1.read) }
        .tap { @working_buffer.gsub!(/end\s*\z/m, '') }

      @spec = Gem::Specification.load(@gemspec_path.to_s)
    end

    def current_value_for(attribute)
      attribute = attribute.to_s
      value = @readonly_buffer
                .match(/spec\.#{attribute} = (?<value>.*?)spec\.\w+ = /m)
                &.named_captures
                &.fetch('value')

      raise "Attribute #{attribute} not found in gemspec" unless value

      value.strip
    end

    #  /(?:(?<opening>)(?!end))(?:\s?end\s?)+\z/m

    def replace_value_for(buffer, attribute, value)
      attribute = attribute.to_s
      #    buffer.gsub!(/spec\.#{attribute} = (?<value>.*?)(?=\s*spec\.\w+ = )/m, "spec.#{attribute} = #{value}\n")
      buffer.gsub!(/spec\.#{attribute}\s*=\s*.*?(\n|\r\n|\r)/, "spec.#{attribute} = #{value}\n")
    end

    def strip_authors
      new_authors_value = spec.authors.map(&:strip)
      replace_value_for(@working_buffer, :authors, new_authors_value)
    end

    def add_dependency(name, version)
      new_dependency = "spec.add_dependency '#{name}', '#{version}'"
      @working_buffer.puts(new_dependency)
    end

    def add_dev_dependency(name, version)
      new_dev_dependency = "spec.add_development_dependency '#{name}', '#{version}'"
      @working_buffer.puts(new_dev_dependency)
    end

    def spec
      raise 'Specification not loaded. Call read first.' unless @spec

      @spec
    end

    def replace_text_value(attribute, value)
      replace_value_for @working_buffer, attribute, "\"#{value}\""
    end

    def description=(value)
      replace_text_value(:description, value)
    end

    def summary=(value)
      replace_text_value(:summary, value)
    end

    def required_ruby_version=(value)
      value_with_operator = ">= #{value}"
      replace_text_value(:required_ruby_version, value_with_operator)
    end

    private

    def preserve_selected_attributes(input_buffer)
      buffer = StringIO.new
      IO.copy_stream(input_buffer, buffer)
      buffer_string = buffer.string
      selected_attributes = [:files, :executables, :version]
      map = selected_attributes
              .map(&:to_s)
              .inject({}) { |acc, attr| acc.merge(attr => current_value_for(attr)) }

      map.each do |attr, value|
        replace_value_for(buffer_string, attr, value)
      end
      StringIO.new(buffer_string)
    end

    def remove_todo(buffer)
      new_buffer = Buffer.new
      buffer
        .grep_v(/TODO/)
        .each { new_buffer.puts _1 }

      new_buffer
    end

    def add_frozen_string_literal(buffer)
      new_buffer = Buffer.new
      new_buffer.puts '# frozen_string_literal: true'

      buffer
        .grep_v(/^\s*# frozen_string_literal:/)
        .each { |line| new_buffer.puts(line) }

      new_buffer
    end

    def remove_ending_blank_lines(buffer)
      buffer.gsub!(/\s*\z/, '')
    end

    def remove_comments(buffer)
      new_buffer = Buffer.new
      buffer
        .grep_v(/^\s*#/)
        .each { new_buffer.puts _1 }

      new_buffer
    end

    def squish_blank_lines(buffer)
      buffer.gsub!(/\n{3,}/m, "\n\n")
    end

    def wip_gemspec_path
      @gemspec_path
        .sub_ext('.edit.gemspec')
        .expand_path
    end
  end
end