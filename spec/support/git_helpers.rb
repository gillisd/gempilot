## Runs git in the current directory.
##
##   git("commit", "--allow-empty", "--quiet", "-m", "Initial commit")
##   git_output("log", "-1", "--pretty=%B") # => "Initial commit"
module GitHelpers
  def git(*args)
    Gempilot::Shell.run("git", *args)
  end

  def git_output(*args)
    Gempilot::Shell.capture("git", *args).output.strip
  end
end
