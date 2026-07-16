# frozen_string_literal: true

require_relative "../test_helper"

class VersionTest < Test::Unit::TestCase
  test "VERSION is defined" do
    assert_not_nil RBGL::VERSION
  end

  test "VERSION is a string" do
    assert_kind_of String, RBGL::VERSION
  end

  test "VERSION follows semantic versioning" do
    assert_match(/\A\d+\.\d+\.\d+/, RBGL::VERSION)
  end

  test "component versions match the gem version" do
    assert_equal RBGL::VERSION, RBGL::Engine::VERSION
    assert_equal RBGL::VERSION, RBGL::GUI::VERSION
  end
end
