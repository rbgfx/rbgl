# frozen_string_literal: true

require_relative "../../test_helper"

class BackendFactoryTest < Test::Unit::TestCase
  test "build creates file backend" do
    backend = RBGL::GUI::BackendFactory.build(
      :file,
      width: 64,
      height: 48,
      title: "Test"
    )

    assert_kind_of RBGL::GUI::FileBackend, backend
  end

  test "build returns backend instances as-is" do
    backend = RBGL::GUI::FileBackend.new(32, 32)

    assert_same backend, RBGL::GUI::BackendFactory.build(
      backend,
      width: 32,
      height: 32,
      title: "Ignored"
    )
  end

  test "native_backend_key prefers wayland when available" do
    key = RBGL::GUI::BackendFactory.send(
      :native_backend_key,
      platform: "x86_64-linux",
      env: { "WAYLAND_DISPLAY" => "wayland-0", "DISPLAY" => ":0" }
    )

    assert_equal :wayland, key
  end

  test "native_backend_key falls back to x11" do
    key = RBGL::GUI::BackendFactory.send(
      :native_backend_key,
      platform: "x86_64-linux",
      env: { "DISPLAY" => ":0" }
    )

    assert_equal :x11, key
  end

  test "native_backend_key selects cocoa on darwin" do
    key = RBGL::GUI::BackendFactory.send(
      :native_backend_key,
      platform: "arm64-darwin",
      env: {}
    )

    assert_equal :cocoa, key
  end

  test "build raises for unknown backend" do
    assert_raise(RuntimeError) do
      RBGL::GUI::BackendFactory.build(:unknown, width: 1, height: 1, title: "Test")
    end
  end
end
