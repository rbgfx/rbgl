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

  test "on requires a block" do
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: :file,
      output_dir: @tmpdir
    )

    assert_raise(ArgumentError) { window.on(:key_press) }
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

  test "validates target fps before building a backend" do
    window = DetectBackendWindow.allocate

    assert_raise(ArgumentError) do
      window.send(:initialize, width: 120, height: 80, backend: :auto, target_fps: 0)
    end

    assert_nil window.build_backend_calls
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

  test "poll_events_raw delegates to backend without dispatching handlers" do
    backend = SpyWindowBackend.new(100, 100)
    backend.raw_events = [{ type: :resize, width: 320, height: 240 }]
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)
    called = false
    window.on(:resize) { called = true }

    assert_equal [{ type: :resize, width: 320, height: 240 }], window.poll_events_raw
    assert_equal [320, 240], [window.width, window.height]
    assert_equal [320, 240], [window.context.width, window.context.height]
    assert_equal [[320, 240]], backend.resize_calls
    assert_false called
  end

  test "close delegates to backend" do
    backend = SpyWindowBackend.new(100, 100)
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)

    window.close

    assert_equal 1, backend.close_count
    assert_true backend.should_close?
  end

  test "close stops an active render loop before another present" do
    backend = MockLoopBackend.new(100, 100, max_frames: 10)
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend, target_fps: nil)
    frames = 0

    window.run do
      frames += 1
      window.close
    end

    assert_equal 1, frames
    assert_equal 0, backend.present_count
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
  attr_writer :present_results, :close_after_first_poll

  def initialize(width, height, title = "RBGL", max_frames: 2)
    super(width, height, title)
    @present_count = 0
    @poll_count = 0
    @closed = false
    @should_close = false
    @max_frames = max_frames
    @events = []
    @present_results = []
    @close_after_first_poll = false
  end

  def present(_framebuffer)
    @present_count += 1
    return true if @present_results.empty?

    @present_results.shift
  end

  def poll_events
    @poll_count += 1
    @should_close = true if @close_after_first_poll && @poll_count == 1
    @events.shift
  end

  def should_close?
    @should_close || @present_count >= @max_frames
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

  test "cleanup errors do not mask frame callback errors and close can be retried" do
    backend = MockLoopBackend.new(100, 100, max_frames: 10)
    close_attempts = 0
    backend.define_singleton_method(:close) do
      close_attempts += 1
      raise "close failed" if close_attempts == 1

      @closed = true
    end
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)

    error = assert_raise(RuntimeError) { window.run { raise "render failed" } }
    window.close

    assert_equal "render failed", error.message
    assert_equal 2, close_attempts
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

  test "render loop throttles to its target frame rate" do
    times = [0.0, 0.0, 0.005, 0.02, 0.025, 0.04, 0.045]
    sleeps = []
    render_loop = RBGL::GUI::Window::RenderLoop.new(
      time_source: -> { times.shift },
      sleeper: ->(duration) { sleeps << duration },
      target_fps: 60
    )
    backend = MockLoopBackend.new(100, 100, max_frames: 3)
    context = RBGL::Engine::Context.new(width: 100, height: 100)

    render_loop.run(backend: backend, context: context, process_events: -> {})

    assert_equal 3, sleeps.length
    assert_in_delta((1.0 / 60) - 0.005, sleeps.first, 0.0001)
  end

  test "render loop compensates for sleep overshoot with absolute deadlines" do
    now = 0.0
    sleeps = []
    render_loop = RBGL::GUI::Window::RenderLoop.new(
      time_source: -> { now },
      sleeper: lambda do |duration|
        sleeps << duration
        now += duration + 0.003
      end,
      target_fps: 100
    )
    backend = MockLoopBackend.new(100, 100, max_frames: 3)
    context = RBGL::Engine::Context.new(width: 100, height: 100)

    render_loop.run(backend: backend, context: context, process_events: -> {}) do
      now += 0.002
    end

    assert_equal 3, sleeps.length
    assert_in_delta 0.008, sleeps[0], 0.0001
    assert_in_delta 0.005, sleeps[1], 0.0001
    assert_in_delta 0.005, sleeps[2], 0.0001
  end

  test "render loop resets an expired deadline after a slow frame" do
    now = 0.0
    sleeps = []
    render_loop = RBGL::GUI::Window::RenderLoop.new(
      time_source: -> { now },
      sleeper: ->(duration) { sleeps << duration; now += duration },
      target_fps: 100
    )
    backend = MockLoopBackend.new(100, 100, max_frames: 3)
    context = RBGL::Engine::Context.new(width: 100, height: 100)
    frame = 0

    render_loop.run(backend: backend, context: context, process_events: -> {}) do
      now += frame.zero? ? 1.0 : 0.002
      frame += 1
    end

    assert_equal 2, sleeps.length
    assert_in_delta 0.008, sleeps.first, 0.0001
  end

  test "fps reports a moving one second window" do
    times = [0.0, 0.0, 0.01, 0.1, 0.11, 1.2, 1.21, 1.3, 1.31]
    render_loop = RBGL::GUI::Window::RenderLoop.new(
      time_source: -> { times.shift },
      sleeper: ->(_duration) {},
      target_fps: nil
    )
    backend = MockLoopBackend.new(100, 100, max_frames: 4)
    context = RBGL::Engine::Context.new(width: 100, height: 100)

    render_loop.run(backend: backend, context: context, process_events: -> {})

    assert_in_delta 10.0, render_loop.fps, 0.001
  end

  test "render loop rejects a non-positive target frame rate" do
    assert_raise(ArgumentError) { RBGL::GUI::Window::RenderLoop.new(target_fps: 0) }
  end

  test "run fails clearly after the one-shot window closes" do
    backend = MockLoopBackend.new(100, 100, max_frames: 1)
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend, target_fps: nil)

    window.run
    error = assert_raise(RuntimeError) { window.run }

    assert_includes error.message, "one-shot"
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

  test "process_events dispatches window event objects" do
    backend = MockLoopBackend.new(100, 100, max_frames: 1)
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: backend
    )

    backend.add_events([[RBGL::GUI::Event.new(:key_press, key: 65)]])

    received = nil
    window.on(:key_press) { |event| received = [event.key, event.type] }

    window.run { |_ctx, _dt| }

    assert_equal [65, :key_press], received
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

  test "run stops before callback and present when events request close" do
    backend = MockLoopBackend.new(100, 100, max_frames: 10)
    backend.close_after_first_poll = true
    window = RBGL::GUI::Window.new(
      width: 100,
      height: 100,
      backend: backend
    )
    frame_count = 0

    window.run do |_ctx, _dt|
      frame_count += 1
    end

    assert_equal 0, frame_count
    assert_equal 0, backend.present_count
    assert_true backend.closed
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
    window.on(:resize) do |event|
      callback_dims = [event.width, event.height, window.width, window.height]
    end

    window.send(:process_events)

    assert_equal 320, window.width
    assert_equal 240, window.height
    assert_equal 320, window.context.width
    assert_equal 240, window.context.height
    assert_equal [[320, 240]], backend.resize_calls
    assert_equal [320, 240, 320, 240], callback_dims
  end

  test "failed backend resize leaves window and context dimensions unchanged" do
    backend = SpyWindowBackend.new(100, 100)
    backend.poll_events_result = [RBGL::GUI::Event.new(:resize, width: 320, height: 240)]
    backend.define_singleton_method(:resize) { |_width, _height| raise "allocation failed" }
    window = RBGL::GUI::Window.new(width: 100, height: 100, backend: backend)

    assert_raise(RuntimeError) { window.send(:process_events) }
    assert_equal [100, 100], [window.width, window.height]
    assert_equal [100, 100], [window.context.width, window.context.height]
  end
end
