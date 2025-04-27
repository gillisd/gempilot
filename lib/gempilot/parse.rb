require 'prism'
require 'benchmark'
require 'delegate'
require 'observer'
require 'forwardable'
require 'stringio'
require 'singleton'

# using this singleton for now to hold the client, will eventually use a session object or context object but this
# is beneficial for productivity right now
module Lightrope
  extend SingleForwardable

  class ClientProvider
    include Singleton

    attr_accessor :root_client
  end

  class TreeWatcher
    include Observable

    def initialize(result)
      @result = result
      @node_types = Set.new
      @visitor_klass = Class.new(Prism::Visitor)
      @visitors = {}
    end

    def receive_node(node)
      # eventually can keep track of seen nodes here for more advanced calls/caching/only once guarantees, but
      # for now just give the green light to broadcast every received node
      changed
    end

    def add_subscriber(subscriber, method)
      add_observer(subscriber)
      if @node_types.add? method
        @visitors[method] = create_visitor(method)
      end
      self
    end

    def trigger(method)
      visitor = @visitors[method]
      @result.accept visitor
    end

    def create_visitor(method)
      @visitor_klass.new.tap do |v|
        self.tap do |this|
          v.define_singleton_method method do |basic_node|
            node = Lightrope::Node.wrap(basic_node)
            this.receive_node node
            this.notify_observers node
          end
        end
      end
    end
  end

  class Iterator
    include Enumerable

    def names(&block)
      if block_given?
        each(&block)
      else
        enum_for(:names)
      end
    end

    def on_start(&block)
      @init_block = block
    end

    def each
      if block_given?
        fiber = Fiber.new(&method(:start_streaming))

        while (nextval = fiber.resume) && fiber.alive?
          yield nextval
        end
      else
        enum_for(__method__)
      end
    end

    def update(node)
      Fiber.yield node
    end

    private

    def start_streaming
      @init_block.call(self)
    end
  end

  module Helpers
    def require_calls
      foows = call_nodes
                .select { |node| node in { name: :require } }

      foows.map { |node| RequireCallNode.wrap(node) }
    end

    def method_definitions
      def_nodes.reject do |node|
        node in { receiver: Prism::SelfNode }
      end
    end

    def singleton_method_definitions
      def_nodes.select do |node|
        node in { receiver: Prism::SelfNode }
      end
    end

    def all_modules(&block)
      module_nodes(&block)
    end
  end

  class Decorator < SimpleDelegator
    def self.wrap(prism_node)

      return prism_node if prism_node.is_a?(self)
      klass_name = klass_name_for_prism_node(prism_node)

      needs_concrete_klass = [Lightrope::Decorator, Lightrope::Node].include?(self)
      klass = needs_concrete_klass ? Lightrope.const_get(klass_name) : self
      klass.new(prism_node)
    end

    def to_hash
      deconstruct_keys(nil)
    end

    alias to_h to_hash

    #
    # this enhanced version of deconstruct_keys allows for passing in symbols of methods that may
    # not be matchable by default in the delegate
    #
    def deconstruct_keys(keys)
      fetch_all = keys.nil? || keys.empty?
      keys ||= []
      extra_keys = keys - base_keys
      extra_keys.each { |key| __getobj__.respond_to?(key) || raise(ArgumentError, "Invalid key: #{key}") }
      regular_keys = base_keys & keys
      extra_results = extra_keys.inject({}) { |hash, k| hash.merge(k => try_wrap(__getobj__.public_send(k))) }

      regular_result = (
        case [fetch_all, regular_keys]
        in true, [] then super
        in false, [] then {}
        else super(regular_keys)
        end
      ).then { |result| result.transform_values { |v| try_wrap(v) } }
      regular_result.merge(extra_results)
    end

    private

    def self.klass_name_for_prism_node(prism_node)
      prism_node
        .class
        .name
        .split('::')
        .last
        .to_sym
    end

    def try_wrap(object)
      if [Prism::Node, Prism::Location].any? { object.is_a?(_1) }
        self.class.wrap(object)
      else
        object
      end
    end

    def method_missing(...)
      result = super
      try_wrap(result)
    end

    def base_keys
      __getobj__.deconstruct_keys(nil).keys
    end
  end

  class Node < Decorator
    def has_ancestor?(node)
      node.has_descendant?(self)
    end

    def has_descendant?(other_node)
      all_descendants(other_node).any? { |descendant| descendant.same?(other_node) }
    end

    def all_between(other_node)
      case [has_descendant?(other_node), has_ancestor?(other_node)]
      in true, false then all_descendants(other_node)
      in false, true then other_node.all_descendants(self)
      in false, false then []
      else raise ArgumentError, "Cannot compare nodes that are not related"
      end
    end

    def same?(other_node)
      node_id == other_node.node_id
    end

    def tunnel_to(line)
      tunneled_descendants(line, 0)
    end

    protected

    def all_descendants(other_node)
      other_node => { location: { start_column: column }, start_line: line }
      tunneled_descendants(line, column)
    end

    private

    def tunneled_descendants(line, column)
      tunnel(line, column).map { |d| Decorator.wrap(d) }
    end
  end

  class Location < Decorator

  end

  class CallNode < Lightrope::Node
    def arguments
      self => { arguments: { arguments: Array => args } }
      args
    end
  end

  class Client
    include Helpers

    def self.from_code(code)
      result = Prism.parse(code)
      new(result)
    end

    def initialize(result)
      @result = result
    end

    def to_source
      @result.source.source
    end

    #
    # Finds a node of name <name> of the type <type>
    # Usage:
    #  find_node(type: :class, name: 'MyClass')

    def find_node_at(line)
      node.tunnel_to(line)
    end

    def find_node(type:, name:)
      name = name.to_sym
      visit_method = "#{type}_nodes".to_sym
      raise ArgumentError, "Invalid node type: #{type}" unless respond_to?(visit_method)
      case public_send(visit_method).to_a
      in [*, { name: ^name } => node, *] then node
      else nil
      end
    end

    def node
      if @result.respond_to? :value
        Node.wrap(@result.value)
      else
        Node.wrap(@result)
      end
    end

    private

    def method_missing(name, *args, **kwargs, &block)
      super unless respond_to_missing?(name)
      method_name = get_visit_method(name)
      build_iterator(method_name).to_enum
    end

    def respond_to_missing?(name, include_private = false)
      Prism::Visitor.instance_methods.include?(get_visit_method(name)) || super
    end

    def build_iterator(method_name)
      iterator = Iterator.new
      tree_watcher = build_tree_watcher
      tree_watcher.add_subscriber(iterator, method_name)
      iterator.on_start do
        tree_watcher.trigger(method_name)
      end
      iterator
    end

    def get_visit_method(keyword)
      node_type = (
        case keyword
        in /^([a-z]+)_nodes$/ then $1
        in /^[a-z]+s$/ then $1
        in /^visit_([a-z]+[^s_.-])s?(?:_nodes?)?$/ then $1
        else
          raise ArgumentError, "Invalid node type: #{keyword}"
        end
      )
      "visit_#{node_type}_node".to_sym
    end

    def build_tree_watcher
      TreeWatcher.new(node)
    end
  end

  class RequireCallNode < CallNode

    def requireable
      self.arguments => [{ unescaped: }]
      unescaped
    end
  end

  def_delegator 'Lightrope::Client', :from_code

  node_regex = /^(?:[A-Z][a-z]+)+Node$/
  ::Prism
    .constants
    .map(&:to_s)
    .grep(node_regex)
    .map(&:to_sym)
    .reject { Lightrope.const_defined?(_1) }
    .each { |name| Lightrope.const_set(name, Class.new(Lightrope::Node)) }

  class ClassProxy
    def self.proxy_instance(node)
      new(node)
    end

    def self.proxy_klass(node) end

    def initialize(node)
      @node = node
    end

    def name
      const_path.join('::')
    end

    def methods
      method_definitions.map(&:name)
    end

    def inspect
      "#<#{name}::Proxy:#{object_id}>"
    end

    private

    def const_path
      [*parent_module_nodes.map(&:name), @node.name]
    end

    def method_definitions
      client.method_definitions
    end

    def client
      @client ||= Lightrope::Client.new(@node)
    end

    def parent_module_nodes
      @parent_module_nodes ||= (
        all_root_modules = root.all_modules
        results = all_root_modules.map do |mod|
          @node.all_between(mod)
               .select { |node| node in ModuleNode }
        end
        # I don't think there is a situation where root.all_modules will return multiple results and each of those will
        # be parents. But leaving here as a reminder that technically the code currently allows for it, which may cause issues.
        # raise "Expected results to have one element but had more than 1: #{results}" if results.flatten(1).size > 1

        results.flatten
      )
    end

    def root
      ClientProvider.instance.root_client
    end
  end
end

module Bar

end

class Editor
  def initialize(file)
    @file = Pathname(file)
    @working_buffer = StringIO.new(source)
  end

  def add_method(method_name, &block)
    last_method = @lightrope.method_definitions.last
    file, line_no = block.source_location

    new_client = Lightrope.from_code(File.read(file))

    node = new_client
             .find_node_at(line_no + 1)
             .find { _1 in Lightrope::BlockNode }

    node => { body: }

    end_line, start_column = get_coordinates(last_method)

    insert_after end_line, start_column do
      <<~RUBY

        def #{method_name}
          #{body.slice}
        end
      RUBY
    end
  end

  def add_require(requireable)
    last_require = @lightrope.require_calls.last
    end_line, start_column = get_coordinates(last_require)

    insert_after end_line, start_column do
      <<~RUBY
        require '#{requireable}'
      RUBY
    end
  end

  def save
    @file.open('w') do |f|
      f.write(@working_buffer.string)
      f.truncate(@working_buffer.size)
    end
  end

  def print
    puts @working_buffer.string
  end

  def source
    lightrope.to_source
  end

  def lightrope
    @lightrope ||= Lightrope::Client.from_code(@file.read)
  end

  def insert_after(line_no, start_column = 0)
    buffer = StringIO.new
    @working_buffer.rewind
    enum = @working_buffer.each_line
    line_no.times do
      buffer.puts enum.next
    end
    input = yield.gsub(/^\b*/, Array.new(start_column) { ' ' }.join)
    buffer.puts input
    loop do
      begin
        line = enum.next
        buffer.puts line
      rescue StopIteration
        break
      end
    end
    @working_buffer = buffer
  end

  private

  def get_coordinates(last_require)
    end_line, start_column = (
      case last_require
      in nil then [3, 0]
      in { end_line: nil, start_column: nil } then [3, 0]
      in { end_line: Integer => end_line, start_column: Integer => start_column } then [end_line, start_column]
      end
    )
    [end_line, start_column]
  end
end

module TestModule
  module TestNestedModule
    class TestClass

      def some_test_method
        puts 'test'
      end
    end
  end
end

root_path = Bundler.root
path = root_path.join('lib/gempilot.rb')
source = path.read

lightrope = Lightrope.from_code(source)
Lightrope::ClientProvider.instance.root_client = lightrope

require_calls = lightrope.require_calls
puts "file requires the following: #{require_calls.map(&:requireable).join(', ')}"
puts

nodes = lightrope.class_nodes
puts "found class nodes: #{nodes.map(&:name).join(', ')}"
puts

puts "now use proxy to get full names and methods: "

nodes.each do |n|
  proxy = Lightrope::ClassProxy.proxy_instance(n)
  puts "#{proxy.name} has methods: #{proxy.methods.join(', ')}"
end

# last_require_call = lightrope.require_calls.last
# end_line = last_require_call.end_line
# puts end_line

bar = lightrope.find_node(type: :module, name: 'Gempilot')
foo = lightrope.find_node(type: :def, name: 'cool')
e = Editor.new(path)
# e.add_require('observer')
e.add_method :again do
  foo = 'bar'

  stuff = 1 + 1
  puts stuff
end

l = Lightrope.from_code(File.read(__FILE__))
l.block_nodes.to_a
e.save















