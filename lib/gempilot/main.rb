#!/usr/bin/env ruby

# frozen_string_literal: true
require 'open3'
require 'optparse'
require 'fileutils'
require 'tempfile'
require 'stringio'
require 'pathname'

autoload :RuboCop, 'rubocop'

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
      a << '--autocorrect' if autocorrect
      a << '--safe-auto-correct' if safe_autocorrect
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

class BundlerRunner
  include FileUtils

  def initialize(gem_name:, github_user:, executable:)
    @gem_name = gem_name
    @github_user = github_user
    @executable = executable
    @command_buffer = StringIO.new
  end

  def gemspec_path
    Pathname.new(@gem_name)
      .join("#{@gem_name}.gemspec")
      .expand_path
  end

  def install
    chdir @gem_name do
      system('bundle install', out: $stdout, err: $stderr)
    end
  end

  def create_gem
    build_command
    status = system(@command_buffer.string, out: $stdout, err: $stderr)
    if status
      puts "Gem #{@gem_name} created successfully!"
    else
      puts "Failed to create gem #{@gem_name}."
    end
    install
  end

  private

  def build_command
    @command_buffer.tap do |cb|
      cb.write 'bundle gem '
      cb.write "--github-username #{@github_user} "
      cb.write '--exe ' if @executable
      cb.write '--linter=rubocop '
      cb.write @gem_name.to_s
    end
  end
end

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

class GemSpecEditor
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

required_options = [:summary, :github_user, :ruby_version]
options = { executable: false, description: nil, github_user: nil, ruby_version: nil }
parser = OptionParser.new do |o|
  o.require_exact = true
  o.on('--github-user GITHUB_USER', "The author's github user name. Example: \"user/repo\"")
  o.on('--summary SUMMARY', 'The summary of the gem. Example: "A simple gem"')
  o.on('--description DESCRIPTION', '(OPTIONAL) The description of the gem. Example: "A simple gem that does something"')
  o.on('--executable', '(OPTIONAL) Create an executable file in ./exe')
  o.on('--ruby-version VERSION', 'The minimum Ruby version required for the gem. Example: ">= 3.3"')

  o.on('-h', '--help') do
    puts o
    exit
  end
end

parser.parse!(into: options)

gem_name = ARGV.shift

if gem_name.nil? || gem_name.empty?
  puts 'Please provide a gem name'
  exit 1
end

formatted_options = options
  .transform_keys(&:to_s)
  .transform_keys { _1.gsub('-', '_') }
  .transform_keys(&:to_sym)

if (missing_options = required_options - options.keys) && missing_options.any?
  puts "Missing required options: #{missing_options.map(&:to_s).join(', ')}"
  exit 1
end

runner = BundlerRunner.new(gem_name:, **formatted_options.slice(:github_user, :executable))
runner.create_gem

rest = formatted_options.tap do |f|
  f.delete(:github_user)
  f.delete(:executable)
end

class String
  def tac
    lines = self.lines
    lines.reverse.join
  end
end

class RubyEditor
  attr_reader :working_buffer

  def initialize(path, &block)
    @pathname = Pathname.new(path)

    @working_buffer = Buffer.new(@pathname.read)
    @rest_blocks = []
    @scanner = StringScanner.new(@working_buffer.read)
    setup
    return unless block_given?

    block.call(self)
    finalize
  end

  def preview
    $stdout.puts @working_buffer.read
  end

  def puts(...)
    @working_buffer.puts(...)
  end

  def print(...)
    @working_buffer.print(...)
  end

  def finalize
    @rest_blocks.reverse.each { @working_buffer.write(_1) }
    #    @working_buffer.write(@rest_buffer.read)
    self
  end

  private

  def setup
    seek_opening
    seek_public_entry
  end

  def seek_opening
    @scanner.check_until(closing_regexp)
    @working_buffer = Buffer.new(@scanner.pre_match)
    @rest_blocks << @scanner.matched
    self
  end

  def seek_public_entry
    scanner = StringScanner.new(@working_buffer.read.lines.reverse.join)
    reversed_position = scanner.skip_until(/(?<opening>public|private|protected)/)
    target_position = scanner.string.size - reversed_position
    scanner.string = @working_buffer.read
    scanner.pos = target_position
    @rest_blocks << scanner.rest
    @working_buffer = Buffer.new(@working_buffer.read[0...target_position])
    self
  end

  def closing_regexp
    /(?<closing>(?:\s*end\s*)+\z)/m
  end
end

GemSpecEditor.new(runner.gemspec_path) do |e|
  e.strip_authors
  e.summary = rest[:summary] if rest[:summary]
  e.required_ruby_version = rest[:required_ruby_version] if rest[:required_ruby_version]
end
