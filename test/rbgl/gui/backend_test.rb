# frozen_string_literal: true

require_relative "../../test_helper"

class BackendTest < Test::Unit::TestCase
  test "initializes with width, height, and title" do
    backend = RBGL::GUI::Backend.new(640, 480, "Test")
    assert_equal 640, backend.width
    assert_equal 480, backend.height
    assert_equal "Test", backend.title
  end

  test "default title is RBGL" do
    backend = RBGL::GUI::Backend.new(640, 480)
    assert_equal "RBGL", backend.title
  end

  test "initialize ignores forwarded keyword options from subclasses" do
    backend_class = Class.new(RBGL::GUI::Backend) do
      def initialize(width, height, title = "RBGL", env: {}, roundtrip_timeout: 0.1)
        @env = env
        @roundtrip_timeout = roundtrip_timeout
        super
      end
    end

    backend = backend_class.new(640, 480, "Test", env: { "DISPLAY" => ":1" }, roundtrip_timeout: 1.0)

    assert_equal 640, backend.width
    assert_equal 480, backend.height
    assert_equal "Test", backend.title
  end

  test "present raises NotImplementedError" do
    backend = RBGL::GUI::Backend.new(640, 480)
    assert_raise(NotImplementedError) do
      backend.present(nil)
    end
  end

  test "poll_events raises NotImplementedError" do
    backend = RBGL::GUI::Backend.new(640, 480)
    assert_raise(NotImplementedError) do
      backend.poll_events
    end
  end

  test "poll_events_raw converts portable events to hashes" do
    backend = Class.new(RBGL::GUI::Backend) do
      def poll_events
        [RBGL::GUI::Event.new(:key_press, key: :escape), Object.new]
      end
    end.new(640, 480)

    assert_equal [{ type: :key_press, key: :escape }], backend.poll_events_raw
  end

  test "resize updates backend dimensions" do
    backend = RBGL::GUI::Backend.new(640, 480)

    backend.resize(800, 600)

    assert_equal 800, backend.width
    assert_equal 600, backend.height
  end

  test "should_close? raises NotImplementedError" do
    backend = RBGL::GUI::Backend.new(640, 480)
    assert_raise(NotImplementedError) do
      backend.should_close?
    end
  end

  test "close raises NotImplementedError" do
    backend = RBGL::GUI::Backend.new(640, 480)
    assert_raise(NotImplementedError) do
      backend.close
    end
  end

  test "set_pixels presents RGBA data through the portable framebuffer API" do
    backend = Class.new(RBGL::GUI::Backend) do
      attr_reader :framebuffer

      def present(framebuffer)
        @framebuffer = framebuffer
        true
      end
    end.new(1, 1)

    assert_true backend.set_pixels("\xFF\x00\x00\xFF", 1, 1)
    assert_equal [255, 0, 0, 255], backend.framebuffer.to_rgba_bytes.bytes
  end

  test "native extensions are absent from the portable backend" do
    backend = RBGL::GUI::Backend.new(640, 480)

    assert_false backend.respond_to?(:metal_available?)
    assert_false backend.respond_to?(:native_handle)
  end
  test "backend unavailable is a standard error" do
    assert_kind_of StandardError, RBGL::GUI::BackendUnavailable.new("unavailable")
  end

  test "backend selection error is an argument error" do
    assert_kind_of ArgumentError, RBGL::GUI::BackendSelectionError.new("invalid")
  end
end
