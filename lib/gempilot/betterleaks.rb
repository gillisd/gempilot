module Gempilot
  ## The betterleaks secret-scanning integration for a single gem.
  ##
  ## Composes the files the integration owns -- a tracked pre-commit hook and
  ## CI workflow copied from gempilot's templates, plus task-lib wiring woven
  ## into the gem's Rakefile and +bin/setup+ -- and installs them through a
  ## +generator+: any command mixing in Generator, which supplies the
  ## +mkdir+/+cp+/+chmod+/+skip+/+update+ file verbs. Every part is idempotent,
  ## so a second install changes nothing.
  ##
  ## Shared by +create+ (fresh scaffold; +root+ is the new gem directory) and
  ## +setup betterleaks+ (retrofit; +root+ is the current directory).
  class Betterleaks
    HOOKS_PATH = ".githooks".freeze

    RAKE_WIRING = <<~RUBY.freeze
      require "gempilot/betterleaks_task"
      Gempilot::BetterleaksTask.new
    RUBY

    SETUP_WIRING = "git config core.hooksPath #{HOOKS_PATH}".freeze

    attr_reader :generator, :root

    def initialize(generator, root: ".")
      @generator = generator
      @root = root
    end

    def install
      files.each { it.install(generator) }
    end

    private

    def files
      [hook, workflow, rakefile_wiring, setup_wiring]
    end

    def hook
      Template.new(source: "githooks/pre-commit", dest: at(".githooks/pre-commit"), executable: true)
    end

    def workflow
      Template.new(source: "dotfiles/github/workflows/secrets.yml", dest: at(".github/workflows/secrets.yml"))
    end

    def rakefile_wiring
      Insertion.new(path: at("Rakefile"), snippet: RAKE_WIRING, before: /^task default/)
    end

    def setup_wiring
      Insertion.new(path: at("bin/setup"), snippet: SETUP_WIRING)
    end

    def at(relative)
      File.join(root, relative)
    end
  end
end
