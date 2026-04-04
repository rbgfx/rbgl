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

  test "build_auto_backend falls back from wayland to x11 when wayland init fails" do
    calls = []
    builder = lambda do |backend, **|
      calls << backend
      raise Errno::ENOENT, "missing wayland socket" if backend == :wayland

      backend
    end

    backend = RBGL::GUI::BackendFactory.send(
      :build_auto_backend,
      width: 64,
      height: 48,
      title: "Test",
      platform: "x86_64-linux",
      env: { "WAYLAND_DISPLAY" => "wayland-0", "DISPLAY" => ":0" },
      builder: builder
    )

    assert_equal :x11, backend
    assert_equal [:wayland, :x11], calls
  end

  test "build_auto_backend falls back from wayland when globals are unavailable" do
    calls = []
    builder = lambda do |backend, **|
      calls << backend
      raise RBGL::GUI::BackendUnavailable, "missing globals" if backend == :wayland

      backend
    end

    backend = RBGL::GUI::BackendFactory.send(
      :build_auto_backend,
      width: 64,
      height: 48,
      title: "Test",
      platform: "x86_64-linux",
      env: { "WAYLAND_DISPLAY" => "wayland-0", "DISPLAY" => ":0" },
      builder: builder
    )

    assert_equal :x11, backend
    assert_equal [:wayland, :x11], calls
  end

  test "build_auto_backend raises when every native backend fails" do
    builder = lambda do |_backend, **|
      raise Errno::ECONNREFUSED, "cannot connect"
    end

    error = assert_raise(RuntimeError) do
      RBGL::GUI::BackendFactory.send(
        :build_auto_backend,
        width: 64,
        height: 48,
        title: "Test",
        platform: "x86_64-linux",
        env: { "WAYLAND_DISPLAY" => "wayland-0", "DISPLAY" => ":0" },
        builder: builder
      )
    end

    assert_includes error.message, "wayland"
    assert_includes error.message, "x11"
  end

  test "build raises for unknown backend" do
    assert_raise(RuntimeError) do
      RBGL::GUI::BackendFactory.build(:unknown, width: 1, height: 1, title: "Test")
    end
  end
end
