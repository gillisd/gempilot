## Builds gempilot from this checkout and installs it into its own gem
## directory, so end-to-end specs run the packaged +gempilot+ executable a
## user would. The build packages tracked files only (the gemspec lists
## files with <tt>git ls-files</tt>).
class InstalledGempilot
  ROOT = Pathname(__dir__).parent.parent

  attr_reader :gem_home

  def initialize(dir)
    @gem_home = Pathname(dir) / "gems"
  end

  def install
    package = gem_home.parent / "gempilot.gem"
    quietly("gem", "build", (ROOT / "gempilot.gemspec").to_s, "--output", package.to_s, chdir: ROOT.to_s)
    quietly("gem", "install", "--local", "--ignore-dependencies", "--no-document",
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

  def quietly(*command, **)
    system(*command, out: File::NULL, err: File::NULL, exception: true, **)
  end
end
