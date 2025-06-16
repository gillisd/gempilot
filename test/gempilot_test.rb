# frozen_string_literal: true

require_relative "test_helper"

class TestGempilot < Minitest::Test
  include Support::EnvHelper
  include Gempilot::Commands

  def setup
    super
    @workdir = Pathname.pwd
    @project_dir = Pathname.new(__dir__).parent
    chdir env.workdir
  end

  def teardown
    chdir @workdir
  end

  def test_workdir
    refute_equal Dir.pwd, @workdir.to_s
  end

  def test_that_it_has_a_version_number
    refute_nil ::Gempilot::VERSION
  end

  def gempilot(*args)
    executable = @project_dir.join('exe/gempilot').expand_path.to_s
    final = "#{executable} #{args.join(' ')}"
    sh final
  end

  def test_env
    env.mkdir_p 'foo'
    env
    env.touch 'foo/bar.txt'

    output = gempilot '--summary "another gem" bar'
    output

  end
end
