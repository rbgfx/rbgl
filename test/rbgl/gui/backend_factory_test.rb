# frozen_string_literal: true

require_relative "../../test_helper"
require "rbgl/gui/x11/backend"
require "rbgl/gui/wayland/backend"

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

  test "build rejects construction options for backend instances" do
    backend = RBGL::GUI::FileBackend.new(32, 32)

    assert_raise(ArgumentError) do
      RBGL::GUI::BackendFactory.build(
        backend,
        width: 32,
        height: 32,
        title: "Ignored",
        unexpected: true
      )
    end
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

  test "build_auto_backend exposes native initialization programming errors" do
    builder = lambda do |backend, **|
      raise TypeError, "invalid native descriptor" if backend == :wayland

      backend
    end

    assert_raise(TypeError) do
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
  end

  test "build_auto_backend raises when every auto backend fails" do
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

  test "build raises for removed native backend alias" do
    assert_raise(RBGL::GUI::BackendSelectionError) do
      RBGL::GUI::BackendFactory.build(:native, width: 1, height: 1, title: "Test")
    end
  end

  test "build_specific_backend forwards env to X11 backend" do
    env = { "DISPLAY" => ":42" }
    backend_class = RBGL::GUI::X11::Backend.singleton_class
    backup = :__rbgl_x11_backend_new_for_test__
    calls = []
    fake_backend = Object.new

    backend_class.send(:alias_method, backup, :new)
    backend_class.send(:define_method, :new) do |*args, **kwargs|
      calls << [args, kwargs]
      fake_backend
    end

    result = RBGL::GUI::BackendFactory.send(
      :build_specific_backend,
      :x11,
      width: 64,
      height: 48,
      title: "Test",
      env: env
    )

    assert_same fake_backend, result
    assert_equal env, calls.first[1][:env]
  ensure
    next unless backend_class&.method_defined?(backup)

    backend_class.send(:remove_method, :new)
    backend_class.send(:alias_method, :new, backup)
    backend_class.send(:remove_method, backup)
  end

  test "build_specific_backend forwards env to Wayland backend" do
    env = { "WAYLAND_DISPLAY" => "wayland-42", "XDG_RUNTIME_DIR" => "/tmp/runtime" }
    backend_class = RBGL::GUI::Wayland::Backend.singleton_class
    backup = :__rbgl_wayland_backend_new_for_test__
    calls = []
    fake_backend = Object.new

    backend_class.send(:alias_method, backup, :new)
    backend_class.send(:define_method, :new) do |*args, **kwargs|
      calls << [args, kwargs]
      fake_backend
    end

    result = RBGL::GUI::BackendFactory.send(
      :build_specific_backend,
      :wayland,
      width: 64,
      height: 48,
      title: "Test",
      env: env,
      roundtrip_timeout: 2.0
    )

    assert_same fake_backend, result
    assert_equal env, calls.first[1][:env]
    assert_equal 2.0, calls.first[1][:roundtrip_timeout]
  ensure
    next unless backend_class&.method_defined?(backup)

    backend_class.send(:remove_method, :new)
    backend_class.send(:alias_method, :new, backup)
    backend_class.send(:remove_method, backup)
  end
end
