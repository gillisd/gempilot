require "command_kit"
require Pathname(Dir.home).join("repos/junk/minitest-activate")
require_relative "../../lib/gempilot/parse"

module Gempilot
  class LightropeTest < Minitest::Test
    def test_namespacing
      root_dir = Pathname(__dir__).parent.parent
      # file = root_dir.join('exe/gempilot')
      #    file = root_dir.join('lib/gempilot/generator.rb')
      file = Pathname(Dir.home).join("repos/vault/bin/hydrator")
      # file = Pathname(Dir.home).join('repos/completions/ast/ast.rb')
      code = file.read
      client = Lightrope::Client.from_code(code)
      foo = (client.module_nodes + client.class_nodes).map(&:to_proxy)
      splittables = foo.map { Lightrope::SplittableConstant.new it }
      sources = splittables.zip(splittables.map(&:to_source))
      temp = root_dir.join("tmp")

      splittables.each do |s|
        path = temp.join(s.relative_path)
        path.parent.mkpath
        puts "writing #{path}"
        File.write(path, s.to_source) unless s.empty?
      end
      # puts hashes.map(&:values)

      client.constant_write_nodes

      client.module_nodes.to_a[2].to_proxy.send(:parent_namespace_nodes)
      arr = client.module_nodes + client.class_nodes
      # arr.map { Lightrope::ClassProxy.new(it)  }.map(&:methods)
      # defs = arr.map { [it, Lightrope::Client.new(it).method_definitions] }
      # foo = defs.map { |constant, def_nodes| [constant, def_nodes.map { |def_node| [def_node, constant.all_between(def_node)] } ]}
      proxies = arr.map { Lightrope::ClassProxy.new(it) }
      # proxies.map(&:to_code)
      proxies.each { puts _1.full_name }
      p splittables.map(&:basename)
      namespace_only_constants = proxies.map(&:empty?)

      # class_nodes = client.class_nodes.to_a
      # module_nodes = client.module_nodes.to_a
      # class_nodes

      # all = recurse(client)
      # class_nodes.to_a
    end
  end
end
