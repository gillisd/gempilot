require 'pathname'
require 'forwardable'
require 'rake/tasklib'
require 'thor/actions'
require 'thor/group'
require 'thor/shell'

module Gempilot
  class ContextBuilder
    def initialize(obj)
      @obj = obj
    end

    def method_missing(name, value)
      adjusted_name = name.to_s
        .gsub(/=$/, '')
        .to_sym
      @obj.singleton_class.attr_accessor adjusted_name
      @obj.public_send(name, value)
    end
  end

  class Generator
    include Thor::Actions
    include Thor::Shell

    attr_accessor :file_name

    def initialize(
      file_name:,
      destination_root: __dir__,
      source_root: File.join(__dir__, 'templates'),
      &block
    )
      self.class.source_root source_root
      self.file_name = Pathname.new file_name
      self.destination_root = destination_root
      block.call(self) if block_given?
    end

    def options
      {}
    end

    def self.from_superclass(...)
      []
    end

    def template_name
      current_ext = file_name.extname
      file_name
        .sub_ext("#{current_ext}.tt")
        .to_s
    end

    alias __template__ template

    def template(name = template_name, &block)
      context_builder = ContextBuilder.new self
      block.call context_builder
      __template__(name)
    end
  end

  class TemplateTask < Rake::TaskLib
    extend Forwardable

    delegate [:template_name, :template]: :@generator

    def initialize(name)
      @generator = Gempilot::Generator.new(file_name: name)
    end

    def define(&block)
      file template_name
      file template_name.gsub(/\.tt$/, '') => template_name do
        template(template_name, &block)
      end
    end
  end
end


# short demo
Gempilot::Generator.new(file_name: 'gemz.rb') do |g|
  g.template do |t|
    t.name = 'coolgem'
  end
end

