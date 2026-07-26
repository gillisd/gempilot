module Gempilot
  class CLI
    ## Installs the betterleaks secret-scanning integration into a gem: a
    ## tracked +.githooks/pre-commit+ hook, a +secrets.yml+ CI workflow, and
    ## Rakefile / +bin/setup+ wiring.
    ##
    ## Shared by the +create+ command (fresh scaffold) and the
    ## +setup betterleaks+ command (retrofit into an existing gem). Every
    ## operation is idempotent, so the retrofit command can run repeatedly
    ## without duplicating files or lines.
    ##
    ## Expects the including class to provide Generator methods (+cp+,
    ## +chmod+, +mkdir+, +create_file+, +print_action+) and +colors+.
    module BetterleaksInstaller
      HOOKS_PATH = ".githooks".freeze
      HOOK_DEST = ".githooks/pre-commit".freeze
      WORKFLOW_DEST = ".github/workflows/secrets.yml".freeze
      HOOK_SOURCE = "githooks/pre-commit".freeze
      WORKFLOW_SOURCE = "dotfiles/github/workflows/secrets.yml".freeze
      RAKE_LINES = <<~RUBY.freeze
        require "gempilot/betterleaks_task"
        Gempilot::BetterleaksTask.new
      RUBY
      SETUP_LINE = "git config core.hooksPath #{HOOKS_PATH}".freeze
      DEFAULT_SETUP = <<~BASH.freeze
        #!/usr/bin/env bash
        set -euo pipefail

        bundle install
      BASH

      private

      def install_betterleaks_files(root: ".")
        copy_hook(root)
        copy_workflow(root)
      end

      def copy_hook(root)
        dest = File.join(root, HOOK_DEST)
        return print_skip(dest) if File.exist?(dest)

        mkdir(File.dirname(dest))
        cp HOOK_SOURCE, dest
        chmod "+x", dest
      end

      def copy_workflow(root)
        dest = File.join(root, WORKFLOW_DEST)
        return print_skip(dest) if File.exist?(dest)

        mkdir(File.dirname(dest))
        cp WORKFLOW_SOURCE, dest
      end

      def wire_rakefile(root: ".")
        append_once(File.join(root, "Rakefile"), RAKE_LINES)
      end

      def wire_setup_script(root: ".")
        path = File.join(root, "bin", "setup")
        ensure_setup_script(path)
        append_once(path, SETUP_LINE)
      end

      def ensure_setup_script(path)
        return if File.exist?(path)

        mkdir(File.dirname(path))
        create_file(path, DEFAULT_SETUP)
        chmod "+x", path
      end

      def append_once(path, snippet)
        body = File.exist?(path) ? File.read(path) : ""
        return print_skip(path) if body.include?(snippet.strip)

        write_appended(path, body, snippet)
        print_action "update", path
      end

      def write_appended(path, body, snippet)
        prefix = body.empty? ? "" : "#{body.chomp}\n\n"
        File.write(path, "#{prefix}#{snippet.chomp}\n")
      end

      def print_skip(path)
        puts "\t#{colors.bold(colors.yellow("skip"))}\t#{colors.yellow(path)}"
      end
    end
  end
end
