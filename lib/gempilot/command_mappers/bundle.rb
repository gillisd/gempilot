module Gempilot
  module CommandMappers
    class Bundle < CommandMapper::Command
      command 'bundle' do
        # Subcommand for 'install'
        subcommand 'install' do
          # Binstubs option
          option '--binstubs', name: :binstubs, value: { required: false }, equals: true

          # Clean option
          option '--clean', name: :clean

          # Deployment option
          option '--deployment', name: :deployment

          # Force/redownload options (aliases)
          option '--redownload', name: :redownload
          option '--force', name: :force

          # Frozen option
          option '--frozen', name: :frozen

          # Full index option
          option '--full-index', name: :full_index

          # Gemfile option
          option '--gemfile', name: :gemfile, value: true, equals: true

          # Jobs options
          option '--jobs', name: :jobs, value: true, equals: true
          option '-j', name: :jobs_short, value: true, equals: true

          # Local options
          option '--local', name: :local
          option '--prefer-local', name: :prefer_local

          # Cache options
          option '--no-cache', name: :no_cache
          option '--no-prune', name: :no_prune

          # Path option
          option '--path', name: :path, value: true, equals: true

          # Quiet option
          option '--quiet', name: :quiet

          # Retry option
          option '--retry', name: :retry, value: { required: false }, equals: true

          # Shebang option
          option '--shebang', name: :shebang, value: true, equals: true

          # Standalone option
          option '--standalone', name: :standalone, value: { required: false }, equals: true

          # System option
          option '--system', name: :system

          # Trust policy option
          option '--trust-policy', name: :trust_policy, value: true, equals: true

          # Target rbconfig option
          option '--target-rbconfig', name: :target_rbconfig, value: true, equals: true

          # Group options
          option '--with', name: :with, value: true, equals: true
          option '--without', name: :without, value: true, equals: true

          def capture_command
            runner = Runner.new(command_string)
            runner.run
          end

          # Convenience methods
          def with_binstubs!(directory = nil)
            self.binstubs = directory
          end

          def clean!
            self.clean = true
          end

          def deployment!
            self.deployment = true
          end

          def force!
            self.force = true
          end

          def redownload!
            self.redownload = true
          end

          def frozen!
            self.frozen = true
          end

          def full_index!
            self.full_index = true
          end

          def with_gemfile!(gemfile_path)
            self.gemfile = gemfile_path
          end

          def with_jobs!(number)
            self.jobs = number
          end

          def local!
            self.local = true
          end

          def prefer_local!
            self.prefer_local = true
          end

          def no_cache!
            self.no_cache = true
          end

          def no_prune!
            self.no_prune = true
          end

          def with_path!(path)
            self.path = path
          end

          def quiet!
            self.quiet = true
          end

          def with_retry!(number = nil)
            self.retry = number
          end

          def with_shebang!(shebang)
            self.shebang = shebang
          end

          def standalone!(groups = nil)
            self.standalone = groups
          end

          def system!
            self.system = true
          end

          def with_trust_policy!(policy)
            self.trust_policy = policy
          end

          def with_target_rbconfig!(rbconfig_path)
            self.target_rbconfig = rbconfig_path
          end

          def with_groups!(groups)
            self.with = groups
          end

          def without_groups!(groups)
            self.without = groups
          end
        end

        # Subcommand for 'binstubs'
        subcommand 'binstubs' do
          # Force option
          option '--force', name: :force

          # Path option
          option '--path', name: :path, value: true, equals: true

          # Shebang option
          option '--shebang', name: :shebang, value: true, equals: true

          # Standalone options
          option '--standalone', name: :standalone
          option '--no-standalone', name: :no_standalone
          option '--skip-standalone', name: :skip_standalone

          # All options
          option '--all', name: :all
          option '--no-all', name: :no_all
          option '--skip-all', name: :skip_all

          # All platforms options
          option '--all-platforms', name: :all_platforms
          option '--no-all-platforms', name: :no_all_platforms
          option '--skip-all-platforms', name: :skip_all_platforms

          # No color option
          option '--no-color', name: :no_color

          # Retry options
          option '-r', name: :retry_short, value: true
          option '--retry', name: :retry, value: true, equals: true

          # Verbose options
          option '-V', name: :verbose_short
          option '--verbose', name: :verbose
          option '--no-verbose', name: :no_verbose
          option '--skip-verbose', name: :skip_verbose

          # The gem name argument
          argument :gem_name, required: true, type: CommandMapper::Types::Str.new

          def capture_command
            runner = Runner.new(command_string)
            runner.run
          end

          # Convenience methods
          def force!
            self.force = true
          end

          def with_path!(path)
            self.path = path
          end

          def with_shebang!(shebang)
            self.shebang = shebang
          end

          def standalone!
            self.standalone = true
          end

          def no_standalone!
            self.no_standalone = true
          end

          def all_gems!
            self.all = true
          end

          def no_all!
            self.no_all = true
          end

          def all_platforms!
            self.all_platforms = true
          end

          def no_all_platforms!
            self.no_all_platforms = true
          end

          def no_color!
            self.no_color = true
          end

          def with_retry!(num)
            self.retry = num
          end

          def verbose!
            self.verbose = true
          end

          def no_verbose!
            self.no_verbose = true
          end
        end
        # Subcommand for 'gem'
        subcommand 'gem' do
          # Binary/executable options
          option '--exe', name: :exe
          option '-b', name: :bin
          option '--bin', name: :bin_long
          option '--no-exe', name: :no_exe

          # Code of Conduct options
          option '--coc', name: :coc
          option '--no-coc', name: :no_coc

          # Changelog options
          option '--changelog', name: :changelog
          option '--no-changelog', name: :no_changelog

          # Extension options
          option '--ext', name: :ext, value: { required: false }, equals: true
          option '--no-ext', name: :no_ext

          # Git options
          option '--git', name: :git

          # GitHub username
          option '--github-username', name: :github_username, value: true, equals: true

          # MIT License options
          option '--mit', name: :mit
          option '--no-mit', name: :no_mit

          # Test framework options
          option '-t', name: :test_short, value: true
          option '--test', name: :test, value: { required: false }, equals: true
          option '--no-test', name: :no_test

          # Continuous Integration options
          option '--ci', name: :ci, value: { required: false }, equals: true
          option '--no-ci', name: :no_ci

          # Linter options
          option '--linter', name: :linter, value: { required: false }, equals: true
          option '--no-linter', name: :no_linter

          # RuboCop (legacy option)
          option '--rubocop', name: :rubocop

          # Editor options
          option '-e', name: :edit_short, value: { required: false }, equals: true
          option '--edit', name: :edit, value: { required: false }, equals: true

          # The gem name argument
          argument :gem_name, required: true, type: CommandMapper::Types::Str.new

          def capture_command
            runner = Runner.new(command_string)
            runner.run
          end

          # Convenience methods for test frameworks
          def minitest!
            self.test = 'minitest'
          end

          def rspec!
            self.test = 'rspec'
          end

          def test_unit!
            self.test = 'test-unit'
          end

          # Convenience methods for CI services
          def github_ci!
            self.ci = 'github'
          end

          def gitlab_ci!
            self.ci = 'gitlab'
          end

          def circle_ci!
            self.ci = 'circle'
          end

          # Convenience methods for linters
          def rubocop_linter!
            self.linter = 'rubocop'
          end

          def standard_linter!
            self.linter = 'standard'
          end

          # Convenience methods for extensions
          def c_extension!
            self.ext = 'c'
          end

          def rust_extension!
            self.ext = 'rust'
          end

          # Convenience method to enable binary creation
          def with_binary!
            self.exe = true
          end

          # Convenience method to enable MIT license
          def with_mit_license!
            self.mit = true
          end

          # Convenience method to enable Code of Conduct
          def with_coc!
            self.coc = true
          end

          # Convenience method to enable Changelog
          def with_changelog!
            self.changelog = true
          end

          # Convenience method to enable Git initialization
          def with_git!
            self.git = true
          end

          # Convenience method to enable RuboCop (legacy)
          def with_rubocop!
            self.rubocop = true
          end

          # Convenience method to enable C extensions (alias)
          def with_extensions!
            self.ext = true
          end

          # Method to set the gem name

          # Method to set editor
          def editor=(editor_name)
            self.edit = editor_name
          end

          # Disable methods for convenience
          def no_tests!
            self.no_test = true
          end

          def no_ci!
            self.no_ci = true
          end

          def no_linter!
            self.no_linter = true
          end

          def no_extensions!
            self.no_ext = true
          end

          def no_mit!
            self.no_mit = true
          end

          def no_coc!
            self.no_coc = true
          end

          def no_changelog!
            self.no_changelog = true
          end

          def no_exe!
            self.no_exe = true
          end
        end
      end
      # Subcommand for 'config'
      subcommand 'config' do
        # Global options for all config operations
        option '--local', name: :local
        option '--global', name: :global
        option '--parseable', name: :parseable

        # Subcommand for 'list'
        subcommand 'list' do
          def capture_command
            runner = Runner.new(command_string)
            runner.run
          end

          def local!
            self.local = true
          end

          def global!
            self.global = true
          end

          def parseable!
            self.parseable = true
          end
        end

        # Subcommand for 'get'
        subcommand 'get' do
          # Configuration name argument
          argument :name, required: true, type: CommandMapper::Types::Str.new

          def capture_command
            runner = Runner.new(command_string)
            runner.run
          end

          def local!
            self.local = true
          end

          def global!
            self.global = true
          end

          def parseable!
            self.parseable = true
          end
        end

        # Subcommand for 'set'
        subcommand 'set' do
          # Configuration name and value arguments
          argument :name, required: true, type: CommandMapper::Types::Str.new
          argument :value, required: true, type: CommandMapper::Types::Str.new

          def capture_command
            runner = Runner.new(command_string)
            runner.run
          end

          def local!
            self.local = true
          end

          def global!
            self.global = true
          end

          # Common configuration convenience methods
          def path!(path)
            self.name = 'path'
            self.value = path
          end

          def without!(groups)
            self.name = 'without'
            self.value = groups
          end

          def with!(groups)
            self.name = 'with'
            self.value = groups
          end

          def deployment!(enabled = true)
            self.name = 'deployment'
            self.value = enabled.to_s
          end

          def jobs!(count)
            self.name = 'jobs'
            self.value = count.to_s
          end

          def bin!(directory)
            self.name = 'bin'
            self.value = directory
          end

          def gemfile!(gemfile_path)
            self.name = 'gemfile'
            self.value = gemfile_path
          end

          def shebang!(shebang)
            self.name = 'shebang'
            self.value = shebang
          end

          def clean!(enabled = true)
            self.name = 'clean'
            self.value = enabled.to_s
          end

          def frozen!(enabled = true)
            self.name = 'frozen'
            self.value = enabled.to_s
          end

          def retry!(count)
            self.name = 'retry'
            self.value = count.to_s
          end

          def timeout!(seconds)
            self.name = 'timeout'
            self.value = seconds.to_s
          end

          def build_option!(gem_name, flags)
            self.name = "build.#{gem_name}"
            self.value = flags
          end

          def local_git!(gem_name, path)
            self.name = "local.#{gem_name}"
            self.value = path
          end

          def mirror!(source_url, mirror_url)
            self.name = "mirror.#{source_url}"
            self.value = mirror_url
          end

          def ssl_ca_cert!(cert_path)
            self.name = 'ssl_ca_cert'
            self.value = cert_path
          end

          def ssl_client_cert!(cert_path)
            self.name = 'ssl_client_cert'
            self.value = cert_path
          end

          def ssl_verify_mode!(mode)
            self.name = 'ssl_verify_mode'
            self.value = mode
          end
        end

        # Subcommand for 'unset'
        subcommand 'unset' do
          # Configuration name argument
          argument :name, required: true, type: CommandMapper::Types::Str.new

          def capture_command
            runner = Runner.new(command_string)
            runner.run
          end

          def local!
            self.local = true
          end

          def global!
            self.global = true
          end

          # Convenience methods for common unset operations
          def path!
            self.name = 'path'
          end

          def without!
            self.name = 'without'
          end

          def with!
            self.name = 'with'
          end

          def deployment!
            self.name = 'deployment'
          end

          def jobs!
            self.name = 'jobs'
          end

          def bin!
            self.name = 'bin'
          end

          def gemfile!
            self.name = 'gemfile'
          end

          def shebang!
            self.name = 'shebang'
          end

          def clean!
            self.name = 'clean'
          end

          def frozen!
            self.name = 'frozen'
          end

          def retry!
            self.name = 'retry'
          end

          def timeout!
            self.name = 'timeout'
          end

          def build_option!(gem_name)
            self.name = "build.#{gem_name}"
          end

          def local_git!(gem_name)
            self.name = "local.#{gem_name}"
          end

          def mirror!(source_url)
            self.name = "mirror.#{source_url}"
          end

          def ssl_ca_cert!
            self.name = 'ssl_ca_cert'
          end

          def ssl_client_cert!
            self.name = 'ssl_client_cert'
          end

          def ssl_verify_mode!
            self.name = 'ssl_verify_mode'
          end
        end

        # Convenience method for general config access (when no explicit operation subcommand is used)
        # This handles cases like: bundle config NAME or bundle config NAME VALUE
        argument :name, required: false, type: CommandMapper::Types::Str.new
        argument :value, required: false, type: CommandMapper::Types::Str.new

        def capture_command
          runner = Runner.new(command_string)
          runner.run
        end

        def local!
          self.local = true
        end

        def global!
          self.global = true
        end

        def parseable!
          self.parseable = true
        end
      end
    end
  end
end

