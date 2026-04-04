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

  test "native_backend_candidates prefer wayland when available" do
    candidates = RBGL::GUI::BackendFactory.send(
      :native_backend_candidates,
      platform: "x86_64-linux",
      env: { "WAYLAND_DISPLAY" => "wayland-0", "DISPLAY" => ":0" }
    )

    assert_equal [:wayland, :x11], candidates
  end

  test "native_backend_candidates fall back to x11" do
    candidates = RBGL::GUI::BackendFactory.send(
      :native_backend_candidates,
      platform: "x86_64-linux",
      env: { "DISPLAY" => ":0" }
    )

    assert_equal [:x11], candidates
  end

  test "native_backend_candidates select cocoa on darwin" do
    candidates = RBGL::GUI::BackendFactory.send(
      :native_backend_candidates,
      platform: "arm64-darwin",
      env: {}
    )

    assert_equal [:cocoa], candidates
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

    error = assert_raise(RBGL::GUI::BackendUnavailable) do
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

  test "native_backend_candidates raises when no display server is available" do
    error = assert_raise(RBGL::GUI::BackendUnavailable) do
      RBGL::GUI::BackendFactory.send(
        :native_backend_candidates,
        platform: "x86_64-linux",
        env: {}
      )
    end

    assert_includes error.message, "No display server"
  end

  test "native_backend_candidates raises on unsupported platform" do
    error = assert_raise(RBGL::GUI::BackendUnavailable) do
      RBGL::GUI::BackendFactory.send(
        :native_backend_candidates,
        platform: "plan9",
        env: {}
      )
    end

    assert_includes error.message, "Unsupported platform"
  end

  test "build raises for unknown backend" do
    assert_raise(RBGL::GUI::BackendSelectionError) do
      RBGL::GUI::BackendFactory.build(:unknown, width: 1, height: 1, title: "Test")
    end
  end
end
