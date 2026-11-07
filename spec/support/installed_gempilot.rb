## Builds gempilot from this repository's working tree and installs it into its own gem directory.
##
##   gempilot = InstalledGempilot.new(Dir.mktmpdir).install
##   Gempilot::Shell.capture("gempilot", "--version", env: gempilot.env).output
##   # => "gempilot 0.3.5\n"
class InstalledGempilot
  ROOT = Pathname(__dir__).parent.parent

  attr_reader :gem_home

  def initialize(dir)
    @gem_home = Pathname(dir) / "gems"
  end

  def install
    package = gem_home.parent / "gempilot.gem"
    index = { "GIT_INDEX_FILE" => (gem_home.parent / "git-index").to_s }
    succeed("git", "add", "--all", chdir: ROOT, env: index)
    succeed("gem", "build", "gempilot.gemspec", "--output", package.to_s, chdir: ROOT, env: index)
    succeed("gem", "install", "--local", "--ignore-dependencies", "--no-document",
            "--install-dir", gem_home.to_s, package.to_s)
    self
  end

  def env
    {
      "GEM_HOME" => gem_home.to_s,
      "GEM_PATH" => [gem_home, *Gem.path].join(File::PATH_SEPARATOR),
      "PATH" => [gem_home / "bin", ENV.fetch("PATH")].join(File::PATH_SEPARATOR),
    }
  end

  private

  def succeed(*command, chdir: Dir.pwd, env: {})
    result = Gempilot::Shell.capture(*command, chdir:, env:, unbundled: true)
    raise "#{command.join(" ")} failed:\n#{result.output}" unless result.success?
  end
end
