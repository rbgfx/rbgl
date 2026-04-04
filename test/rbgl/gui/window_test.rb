# frozen_string_literal: true

require_relative "../../test_helper"
require "tmpdir"

class WindowTest < Test::Unit::TestCase
  setup do
    @tmpdir = Dir.mktmpdir
  end

  teardown do
    FileUtils.rm_rf(@tmpdir)
  end

  test "initializes with file backend" do
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      title: "Test",
      backend: :file,
      output_dir: @tmpdir
    )
    assert_equal 100, window.width
    assert_equal 100, window.height
    assert_kind_of RBGL::Engine::Context, window.context
    assert_kind_of RBGL::GUI::FileBackend, window.backend
  end

  test "context is initialized with correct dimensions" do
    window = RBGL::GUI::Window.new(
      width: 200,
      height: 150,
      backend: :file,
      output_dir: @tmpdir
    )
    assert_equal 200, window.context.width
    assert_equal 150, window.context.height
  end

  test "on registers event handler" do
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: :file,
      output_dir: @tmpdir
    )
    called = false
    window.on(:key_press) { called = true }
    assert_false called
  end

  test "on_key registers key event sugar on the window" do
    backend = SpyWindowBackend.new(100, 100)
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)
    backend.poll_events_result = [RBGL::GUI::Event.new(:key_press, key: 65)]
    received = nil

    window.on_key { |key, action| received = [key, action] }
    window.send(:process_events)

    assert_equal [65, :press], received
  end

  test "on_mouse registers mouse event sugar on the window" do
    backend = SpyWindowBackend.new(100, 100)
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)
    backend.poll_events_result = [RBGL::GUI::Event.new(:mouse_press, x: 12, y: 24, button: 1)]
    received = nil

    window.on_mouse { |x, y, button, action| received = [x, y, button, action] }
    window.send(:process_events)

    assert_equal [12, 24, 1, :press], received
  end

  test "stop sets running to false" do
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: :file,
      output_dir: @tmpdir
    )
    window.stop
  end

  test "present_framebuffer uses context framebuffer by default" do
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: :file,
      output_dir: @tmpdir
    )
    assert_true window.present_framebuffer
    assert File.exist?(File.join(@tmpdir, "frame_00000.ppm"))
  end

  test "present_framebuffer can use custom framebuffer" do
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: :file,
      output_dir: @tmpdir
    )
    fb = RBGL::Engine::Framebuffer.new(50, 50)
    window.present_framebuffer(fb)
  end

  test "present_framebuffer tracks dropped frames when present returns false" do
    backend = SpyWindowBackend.new(100, 100)
    backend.present_result = false
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)

    assert_false window.present_framebuffer
    assert_equal 1, window.dropped_frames
  end

  test "fps returns 0 initially" do
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: :file,
      output_dir: @tmpdir
    )
    assert_equal 0, window.fps
  end

  test "dropped_frames returns 0 initially" do
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: :file,
      output_dir: @tmpdir
    )

    assert_equal 0, window.dropped_frames
  end

  test "raises error for unknown backend" do
    assert_raise(RBGL::GUI::BackendSelectionError) do
      RBGL::GUI::Window.new(
        width: 100,
        height: 100,
        backend: :unknown
      )
    end
  end

  test "accepts Backend instance directly" do
    backend = RBGL::GUI::FileBackend.new(100, 100, "Test", output_dir: @tmpdir)
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: backend
    )
    assert_same backend, window.backend
  end

  test "uses detect_backend for auto backend" do
    window = DetectBackendWindow.new(width: 120, height: 80, title: "Auto", backend: :auto)

    assert_equal [[:auto, 120, 80, "Auto"]], window.build_backend_calls
    assert_kind_of SpyWindowBackend, window.backend
  end

  test "uses detect_backend for native backend" do
    window = DetectBackendWindow.new(width: 90, height: 60, title: "Native", backend: :native)

    assert_equal [[:native, 90, 60, "Native"]], window.build_backend_calls
    assert_kind_of SpyWindowBackend, window.backend
  end

  test "on_resize registers resize event sugar on the window" do
    backend = SpyWindowBackend.new(100, 100)
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)
    backend.poll_events_result = [RBGL::GUI::Event.new(:resize, width: 320, height: 240)]
    received = nil

    window.on_resize { |width, height| received = [width, height] }
    window.send(:process_events)

    assert_equal [320, 240], received
  end

  test "set_pixels delegates dimensions to backend" do
    backend = SpyWindowBackend.new(100, 100)
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)

    window.set_pixels("pixels")

    assert_equal ["pixels", 100, 100], backend.set_pixels_args
  end

  test "metal_available? delegates to backend" do
    backend = SpyWindowBackend.new(100, 100)
    backend.metal_available_value = true
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)

    assert_true window.metal_available?
  end

  test "native_handle delegates to backend" do
    backend = SpyWindowBackend.new(100, 100)
    backend.native_handle_value = :window_handle
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)

    assert_equal :window_handle, window.native_handle
  end

  test "should_close? delegates to backend" do
    backend = SpyWindowBackend.new(100, 100)
    backend.should_close = true
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)

    assert_true window.should_close?
  end

  test "poll_events_raw delegates to backend" do
    backend = SpyWindowBackend.new(100, 100)
    backend.raw_events = [{ type: :key_press }]
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)

    assert_equal [{ type: :key_press }], window.poll_events_raw
  end

  test "close delegates to backend" do
    backend = SpyWindowBackend.new(100, 100)
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)

    window.close

    assert_equal 1, backend.close_count
    assert_true backend.should_close?
  end
end

class SpyWindowBackend < RBGL::GUI::Backend
  attr_reader :presented_framebuffers, :set_pixels_args, :close_count
  attr_reader :resize_calls
  attr_writer :should_close, :poll_events_result, :raw_events, :metal_available_value, :native_handle_value, :present_result

  def initialize(width, height, title = "RBGL")
    super(width, height, title)
    @presented_framebuffers = []
    @poll_events_result = []
    @raw_events = []
    @should_close = false
    @close_count = 0
    @metal_available_value = false
    @native_handle_value = nil
    @resize_calls = []
    @present_result = true
  end

  def present(framebuffer)
    @presented_framebuffers << framebuffer
    @present_result
  end

  def poll_events
    @poll_events_result
  end

  def poll_events_raw
    @raw_events
  end

  def should_close?
    @should_close
  end

  def close
    @close_count += 1
    @should_close = true
  end

  def set_pixels(buffer, width, height)
    @set_pixels_args = [buffer, width, height]
  end

  def resize(width, height)
    @resize_calls << [width, height]
    super
  end

  def metal_available?
    @metal_available_value
  end

  def native_handle
    @native_handle_value
  end
end

class DetectBackendWindow < RBGL::GUI::Window
  attr_reader :build_backend_calls

  private

  def build_backend(backend, width:, height:, title:, **_options)
    @build_backend_calls ||= []
    @build_backend_calls << [backend, width, height, title]
    SpyWindowBackend.new(width, height, title)
  end
end

class MockLoopBackend < RBGL::GUI::Backend
  attr_reader :present_count, :poll_count, :closed
  attr_writer :present_results

  def initialize(width, height, title = "RBGL", max_frames: 2)
    super(width, height, title)
    @present_count = 0
    @poll_count = 0
    @closed = false
    @max_frames = max_frames
    @events = []
    @present_results = []
  end

  def present(_framebuffer)
    @present_count += 1
    return true if @present_results.empty?

    @present_results.shift
  end

  def poll_events
    @poll_count += 1
    @events.shift
  end

  def should_close?
    @present_count >= @max_frames
  end

  def close
    @closed = true
  end

  def add_events(events)
    @events.concat(events)
  end
end

class WindowRunTest < Test::Unit::TestCase
  test "render loop uses monotonic time by default" do
    render_loop = RBGL::GUI::Window::RenderLoop.new
    backend = MockLoopBackend.new(100, 100, max_frames: 1)
    context = RBGL::Engine::Context.new(width: 100, height: 100)
    process_singleton = class << Process; self; end
    backup_method = :__rbgl_original_clock_gettime_for_test__
    calls = []

    process_singleton.send(:alias_method, backup_method, :clock_gettime)
    process_singleton.send(:remove_method, :clock_gettime)
    process_singleton.send(:define_method, :clock_gettime) do |clock_id, *_args|
      calls << clock_id
      1.0
    end

    render_loop.run(backend: backend, context: context, process_events: -> {}) do |_ctx, _dt|
    end

    assert_includes calls, Process::CLOCK_MONOTONIC
  ensure
    next unless process_singleton&.method_defined?(backup_method)

    process_singleton.send(:remove_method, :clock_gettime)
    process_singleton.send(:alias_method, :clock_gettime, backup_method)
    process_singleton.send(:remove_method, backup_method)
  end

  test "run executes frame loop" do
    backend = MockLoopBackend.new(100, 100, max_frames: 3)
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: backend
    )

    frame_count = 0
    window.run do |_ctx, _dt|
      frame_count += 1
    end

    assert_equal 3, frame_count
    assert_equal 3, backend.present_count
    assert_true backend.closed
  end

  test "run closes backend when frame callback raises" do
    backend = MockLoopBackend.new(100, 100, max_frames: 10)
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: backend
    )

    assert_raise(RuntimeError) do
      window.run do |_ctx, _dt|
        raise "boom"
      end
    end

    assert_true backend.closed
  end

  test "run updates fps" do
    backend = MockLoopBackend.new(100, 100, max_frames: 5)
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: backend
    )

    window.run { |_ctx, _dt| }

    assert backend.present_count > 0
    assert window.fps > 0
  end

  test "process_events dispatches events to handlers" do
    backend = MockLoopBackend.new(100, 100, max_frames: 2)
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: backend
    )

    event = RBGL::GUI::Event.new(:key_press, key: 65)
    backend.add_events([[event]])

    received_events = []
    window.on(:key_press) { |e| received_events << e }

    window.run { |_ctx, _dt| }

    assert_equal 1, received_events.size
    assert_equal :key_press, received_events[0].type
  end

  test "process_events dispatches backend callbacks from window events" do
    backend = MockLoopBackend.new(100, 100, max_frames: 1)
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: backend
    )

    backend.add_events([[RBGL::GUI::Event.new(:key_press, key: 65)]])

    received = nil
    window.on_key { |key, action| received = [key, action] }

    window.run { |_ctx, _dt| }

    assert_equal [65, :press], received
  end

  test "run with nil frame callback" do
    backend = MockLoopBackend.new(100, 100, max_frames: 2)
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: backend
    )

    window.run
    assert_equal 2, backend.present_count
  end

  test "run tracks dropped frames when present returns false" do
    backend = MockLoopBackend.new(100, 100, max_frames: 3)
    backend.present_results = [true, false, true]
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: backend
    )

    window.run { |_ctx, _dt| }

    assert_equal 1, window.dropped_frames
  end

  test "process_events ignores non event entries" do
    backend = SpyWindowBackend.new(100, 100)
    backend.poll_events_result = :invalid_payload
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)

    assert_nothing_raised do
      window.send(:process_events)
    end
  end

  test "process_events ignores non event entries and dispatches all handlers" do
    backend = SpyWindowBackend.new(100, 100)
    backend.poll_events_result = [
      "noise",
      RBGL::GUI::Event.new(:key_press, key: 65)
    ]
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)

    received = []
    window.on(:key_press) { |event| received << [:first, event.key] }
    window.on(:key_press) { |event| received << [:second, event.key] }

    window.send(:process_events)

    assert_equal [[:first, 65], [:second, 65]], received
  end

  test "process_events applies resize events before dispatching callbacks" do
    backend = SpyWindowBackend.new(100, 100)
    backend.poll_events_result = [RBGL::GUI::Event.new(:resize, width: 320, height: 240)]
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)

    callback_dims = nil
    window.on_resize { |width, height| callback_dims = [width, height, window.width, window.height] }

    window.send(:process_events)

    assert_equal 320, window.width
    assert_equal 240, window.height
    assert_equal 320, window.context.width
    assert_equal 240, window.context.height
    assert_equal [[320, 240]], backend.resize_calls
    assert_equal [320, 240, 320, 240], callback_dims
  end
end
