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

    def self.client
      instance.root_client
    end

    attr_accessor :root_client
  end

  class SplittableConstant
    attr_reader :proxy

    def initialize(proxy)
      @proxy = proxy
    end

    def name
      demodularized.last
    end

    def empty?
      proxy.empty?
    end

    def basename
      underscore(name)
    end

    def underscore(const)
      CommandKit::Inflector.underscore(const)
    end

    def to_h
      {
        path: relative_path,
        source: to_source
      }

    end

    def to_source
      surrounder = Surrounder.new(proxy)
      if proxy.empty?
        surrounder.render('')
      else
        surrounder.render(proxy.to_inner_source)
      end
    end

    def relative_path
      home = Dir.home
      demodularized[0..-2]
        .map { |namespace| underscore(namespace) }
        .inject(Pathname.new(home)) { |pname, component| pname.join(component) }
        .join(basename)
        .sub_ext('.rb')
        .relative_path_from(home)
    end

    def full_name
      @proxy.full_name
    end

    def demodularized
      full_name.split('::')
    end

    def wrap(&block) end
  end

  class ConstantSplitter
    def initialize(root_node)
      @root_node = root_node
    end

    def to_a
      splittables.map(&:to_s)
    end

    def splittables
      class_nodes = @root_node.class_nodes
      splittables = class_nodes
                      .map { |node| ClassProxy.new(node) }
                      .map { |node| SplittableConstant.new(node) }
    end
  end

  class TreeWatcher
    include Observable

    def initialize(result, recurse: true)
      @recurse = recurse
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
      should_recurse = @recurse # put in scope
      @visitor_klass.new.tap do |v|
        self.tap do |this|
          v.define_singleton_method method do |basic_node|
            node = Lightrope::Node.wrap(basic_node)
            this.receive_node node
            this.notify_observers node
            super(basic_node) if should_recurse
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
      def_nodes(recurse: false).reject do |node|
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
    extend Forwardable

    #    delegate :methods => :__getobj__

    def self.wrap(prism_node)
      # return prism_node if prism_node.is_a?(self)

      case [prism_node, self]
      in ^(self), _ then prism_node # already wrapped
      # in Lightrope::Decorator | Lightrope::Node # needs concrete class
      else
        klass_name = klass_name_for_prism_node(prism_node)
        klass = Lightrope.const_get(klass_name)
        klass.new(prism_node)
      end
      # needs_concrete_klass = [Lightrope::Decorator, Lightrope::Node].include?(self)
      # klass = needs_concrete_klass ? Lightrope.const_get(klass_name) : self
      # klass.new(prism_node)
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
      extra_keys.select! { |key| __getobj__.respond_to?(key) }
      regular_keys = base_keys & keys
      extra_results = extra_keys.inject({}) { |hash, k| hash.merge(k => try_wrap(__getobj__.public_send(k))) }

      regular_result = (
        case [fetch_all, regular_keys]
        in true, [] then super
        in false, [] then {}
        else super(regular_keys)
        end
      )
      regular_result
        .transform_values { |v| try_wrap(v) }
        .merge(extra_results)
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

    def method_missing(name, *args, **kwargs, &block)
      if name == :constant_path
        name
      end
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
      all_descendants_between_and_including(other_node).any? { |descendant| descendant.same?(other_node) }
    end

    def all_between_and_including(other_node)
      case [has_descendant?(other_node), has_ancestor?(other_node)]
      in true, false then all_descendants_between_and_including(other_node)
      in false, true then other_node.all_descendants_between_and_including(self)
      in false, false then []
      else raise ArgumentError, "Cannot compare nodes that are not related"
      end
    end

    def all_between(other_node)
      all_between_and_including(other_node).reject { |node| node.same?(other_node) }
    end

    def same?(other_node)
      node_id == other_node.node_id
    end

    def tunnel_to(line)
      tunneled_descendants(line, 0)
    end

    def to_proxy
      proxy_klass.new(self)
    end

    protected

    def all_descendants_between_and_including(other_node)
      other_node => { location: { start_column: column }, start_line: line }
      tunneled_descendants(line, column).reject { |node| same?(node) }
    end

    private

    def proxy_klass
      klass_name = CommandKit::Inflector.camelize("#{proxy_type}_proxy")
      self
        .class
        .singleton_class
        .nesting
        .last
        .const_get(klass_name)
    end

    def proxy_type
      type.to_s in /^(.+)_node$/
      $1
    end

    def tunneled_descendants(line, column)
      tunnel(line, column).map { |d| Decorator.wrap(d) }
    end
  end

  module Proxyable
    def to_proxy
      query_result = [:module, :class]
                       .filter_map { |type| program_client.find_node(type:, name:) }

      result = (
        case query_result
        in [Lightrope::Node, Lightrope::Node, *]
          raise "Found more than one node for #{name} of type #{type}"
        in [Lightrope::Node => result]
          result
        else
          raise "Could not find node for #{name} of type #{type}"
        end
      )
      result.to_proxy
    end

    def program_client
      ClientProvider.client
    end
  end

  class ConstantReadNode < Node
    include Proxyable
  end

  class ConstantPathNode < Node
    include Proxyable
  end

  class ClassNode < Node
    def to_proxy
      ClassProxy.new(self)
    end
  end

  class ModuleNode < Node
    def to_proxy
      ModuleProxy.new(self)
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
      instance = new(result)
      ClientProvider.instance.root_client = instance
      instance
    end

    def initialize(result)
      @result = result
    end

    def to_source
      # @result.source.source
      @result.slice
    end

    def id
      node.node_id
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

    def method_missing(name, *args, recurse: true, **kwargs, &block)
      super unless respond_to_missing?(name)
      method_name = get_visit_method(name)
      build_iterator(method_name, recurse: recurse).to_enum
    end

    def respond_to_missing?(name, include_private = false)
      Prism::Visitor.instance_methods.include?(get_visit_method(name)) || super
    end

    def build_iterator(method_name, recurse:)
      iterator = Iterator.new
      tree_watcher = build_tree_watcher(recurse: recurse)
      tree_watcher.add_subscriber(iterator, method_name)
      iterator.on_start do
        tree_watcher.trigger(method_name)
      end
      iterator
    end

    def prism_visit_methods
      Prism::Compiler.instance_methods
    end

    def get_visit_method(keyword)
      prism_method_name = keyword
                            &.to_s
                            &.match(/^(?<prism_method_name>.*node)s$/)
                            &.named_captures
                            &.fetch('prism_method_name', nil)
                            &.then { |it| "visit_#{it}" }
                            &.to_sym

      unless prism_visit_methods.include?(prism_method_name)
        raise ArgumentError, "Prism does not support #{keyword}"
      end

      prism_method_name

      # node_type = (
      #   case keyword
      #   in /^([a-z]+)_nodes$/ then $1
      #   in /^[a-z]+s$/ then $1
      #   in /^visit_([a-z]+[^s_.-])s?(?:_nodes?)?$/ then $1
      #   else
      #     $1
      #     # raise ArgumentError, "Invalid node type: #{keyword}"
      #   end
      # )
      # "visit_#{node_type}_node".to_sym
    end

    def build_tree_watcher(recurse:)
      TreeWatcher.new(node, recurse:)
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

  class Proxy
    attr_reader :node

    def self.proxy_instance(node)
      new(node)
    end

    def initialize(node)
      @node = node
    end

    def leading_comments
      @node.leading_comments
    end

    def trailing_comments
      @node.leading_comments
    end

    def full_name
      const_path.join('::')
    end

    def id
      client.id
    end

    def to_source
      @node.slice_lines
    end

    def to_inner_source
      @node.body.slice_lines
    end

    def namespace
      const_path[0..-2].join('::')
    end

    def empty?
      methods.none?
    end

    def methods
      method_definitions.select { @node.all_between(it).reject { it in Lightrope::StatementsNode }.none? }
    end

    def inspect
      "#<#{name}::Proxy:#{object_id}>"
    end

    def to_code
      node_path => [*namespace_nodes, node]

      opening = namespace_nodes
                  .map { |node| p node; node }
                  .map
                  .with_index { |it, i| [" " * i * 2, "module #{it}"].join }
                  .join("\n")
                  .chomp

      closing = namespace_nodes
                  .map
                  .with_index { |_, i| [" " * i * 2, "end"].join }
                  .join("\n")
      [opening, [" " * namespace_nodes.count * 2, node.slice].join, closing].join("\n")
    end

    def parent_namespace_nodes
      indirect_parent_namespace_nodes + direct_parent_namespace_nodes
    end

    private

    def node_path
      [*parent_namespace_nodes, @node]
    end

    def const_path
      node_path.map(&:name)
    end

    def method_definitions
      client.method_definitions
    end

    def client
      @client ||= Lightrope::Client.new(@node)
    end

    def direct_parent_namespace_nodes(target = self.node)
      case target
      in { constant_path: { parent: } }
        [parent, *direct_parent_namespace_nodes(parent)].compact
      in { parent: }
        [parent, *direct_parent_namespace_nodes(parent)].compact
      else
        []
      end
    end

    def indirect_parent_namespace_nodes
      @indirect_parent_namespace_nodes ||= (
        all_root_modules = root.all_modules
        results = all_root_modules.select { it.has_descendant?(@node) }

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

  # class ConstantPathProxy < Proxy
  #   def initialize(node)
  #     super
  #   end
  #
  #   def surround(string)
  #     node in { module_keyword_loc: start_location, end_keyword_loc: end_location }
  #     start_location.slice_lines + string + end_location.slice_lines
  #   end
  # end

  class Surrounder
    attr_reader :proxy

    def initialize(proxy)
      @proxy = proxy
    end

    def render(source)
      identity = proxy.method(:surround).to_proc
      bar = proxy
              .parent_namespace_nodes

      bar = bar
              .map(&:to_proxy)
              .map.with_index { |proxy, level| ->(string) { proxy.method(:surround).to_proc.call(string, level: level) } }
              .reverse

      bar.inject(identity) { |composed, prock| composed >> prock }.call(source)
    end
  end

  module Formatting

    module_function

    def indent(*lines, level:, boost: 0)
      lines.map { |it| " " * (level + (boost * 2)) + it }
    end

    module_function

    def handle_body(string)
      string.split("\n")
            .then { |arr|
              if arr.any?
                initial = arr.first.match(/^(\s*)/)[1]
                arr.map { |line| line.gsub(/^\s{#{initial.length}}/, '') }
              else
                arr
              end
            }
    end
  end

  class ModuleProxy < Proxy
    include Formatting

    def surround(string, level: 0)
      node in { name:, module_keyword:, end_keyword: }
      name = name.to_s
      [
        indent([module_keyword, name].join(' '), level:),
        indent(
          *handle_body(string),
          level:,
          boost: 1
        ),
        indent(end_keyword, level:)
      ].join("\n")
    end
  end

  class ClassProxy < Proxy
    include Formatting

    def surround(string, level: 0)
      node in { name:, class_keyword:, end_keyword: }
      name = name.to_s
      [
        indent([class_keyword, name].join(' '), level:),
        indent(
          *handle_body(string),
          level:,
          boost: 1
        ),
        indent(end_keyword, level:)
      ].join("\n")
    end
  end
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

# demo
#
# easily get an enum of all nodes of any type:
#
# source = File.open('foo.rb')
# lightrope = Lightrope::Client.from_code(source)
#
# lightrope.class_nodes       # all class nodes
# lightrope.class_nodes.last  # last_defined_class_node
# lightrope.methods           # all methods
# lightrope.require_calls     # all require calls
# lightrope
#
#
# Introspect a class/object just like you normally would if it was loaded into the VM, but do it 100% statically
#
# source = File.open('foo.rb')
# foo_proxy = Lightrope::ClassProxy.proxy_instance(source)
# foo_proxy.methods # all methods
# foo_proxy.name # full class name, includes full namespace
# and more
#
#
# find any particular node type with any name in a single call
#
# prism_module_node = lightrope.find_node(type: :module, name: 'Prism')
#
#
# see if a node is an ancestor/descendant of another node in a single call
#
# activesupport = lightrope.find_node(type: :module, name: 'ActiveSupport')
# cache = lightrope.find_node(type: :class, name: 'Cache')
#
# activesupport.has_descendant?(cache) # true
#
#
# Add a method to an existing ruby file underneath the last defined method, using real ruby (no heredocs/strings, etc)
# editor = Editor.new('foo.rb')
# editor.add_method :new_method do
#   puts 'hello world'
# end
#
# editor.save
#
# Add an additional require call to the top of the file, underneath the last require call
# editor = Editor.new('foo.rb')
# editor.add_require 'foo/bar'
#
# editor.save
#

# root_path = Bundler.root
# path = root_path.join('lib/gempilot.rb')
# source = path.read
#
# lightrope = Lightrope.from_code(source)
# Lightrope::ClientProvider.instance.root_client = lightrope
#
# require_calls = lightrope.require_calls
# puts "file requires the following: #{require_calls.map(&:requireable).join(', ')}"
# puts
#
# nodes = lightrope.class_nodes
# puts "found class nodes: #{nodes.map(&:name).join(', ')}"
# puts
#
# puts "now use proxy to get full names and methods: "
#
# nodes.each do |n|
#  proxy = Lightrope::ClassProxy.proxy_instance(n)
#  puts "#{proxy.name} has methods: #{proxy.methods.join(', ')}"
# end
#

# last_require_call = lightrope.require_calls.last
# end_line = last_require_call.end_line
# puts end_line

# bar = lightrope.find_node(type: :module, name: 'Gempilot')
# foo = lightrope.find_node(type: :def, name: 'cool')

# e = Editor.new(path)
# e.add_method :again do
#  foo = 'bar'
#
#  stuff = 1 + 1
#  puts stuff
# end
#
# l = Lightrope.from_code(File.read(__FILE__))
# l.block_nodes.to_a
# e.save
