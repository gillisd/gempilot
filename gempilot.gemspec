require_relative "lib/gempilot/version"

Gem::Specification.new do |spec|
  spec.name = "gempilot"
  spec.version = Gempilot::VERSION
  spec.authors = ["David Gillis"]
  spec.email = ["david@flipmine.com"]
  spec.homepage = "https://github.com/gillisd/gempilot"
  spec.summary = "A toolkit for creating and managing your own rubygems"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.metadata["homepage_uri"] = spec.homepage

  gemspec_file = File.basename(__FILE__)
  files = IO.popen(["git", "ls-files", "-z"], chdir: __dir__, err: IO::NULL) { |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec_file) ||
        f.start_with?("bin/", "test/", "spec/", "features/", ".git", "Gemfile")
    end
  }
  files = Dir.glob("{lib,exe,rakelib}/**/*").push("README.md", "LICENSE.txt", "Rakefile") if files.empty?
  spec.files = files
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "command_kit"
  spec.add_dependency "rake"
  spec.add_dependency "zeitwerk"
  spec.metadata["rubygems_mfa_required"] = "true"
end
