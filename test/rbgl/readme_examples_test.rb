# frozen_string_literal: true

require_relative "../test_helper"
require "open3"
require "rbconfig"
require "tmpdir"

class ReadmeExamplesTest < Test::Unit::TestCase
  ROOT = File.expand_path("../..", __dir__)
  README = File.join(ROOT, "README.md")
  DOCTEST_PATTERN = /<!-- rbgl-doctest: ([\w-]+) -->\s*```ruby\n(.*?)```/m

  test "marked README examples execute successfully" do
    examples = File.read(README).scan(DOCTEST_PATTERN)
    assert_not_empty examples

    examples.each do |name, source|
      Dir.mktmpdir("rbgl-readme") do |directory|
        stdout, stderr, status = Open3.capture3(
          RbConfig.ruby,
          "-I#{File.join(ROOT, 'lib')}",
          stdin_data: source,
          chdir: directory
        )

        assert_predicate status, :success?, "README example #{name} failed:\n#{stdout}\n#{stderr}"
        assert_path_exist File.join(directory, "frames", "frame_00000.ppm") if name == "file-triangle"
      end
    end
  end
end
