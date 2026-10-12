## Writes gem layouts under +lib/+ in the current directory.
module GemLayout
  def write_rival_gem
    Pathname("lib/other").mkpath
    Pathname("lib/other.rb").write("module Other; end\n")
  end
end
