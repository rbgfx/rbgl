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

  test "poll_events_raw returns empty array by default" do
    backend = RBGL::GUI::Backend.new(640, 480)
    assert_equal [], backend.poll_events_raw
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

  test "set_pixels raises NotImplementedError" do
    backend = RBGL::GUI::Backend.new(640, 480)
    assert_raise(NotImplementedError) do
      backend.set_pixels("pixels", 640, 480)
    end
  end

  test "metal_available? returns false by default" do
    backend = RBGL::GUI::Backend.new(640, 480)
    assert_false backend.metal_available?
  end

  test "native_handle returns nil by default" do
    backend = RBGL::GUI::Backend.new(640, 480)
    assert_nil backend.native_handle
  end

  test "on_key stores callback" do
    backend = RBGL::GUI::Backend.new(640, 480)
    called = false
    backend.on_key { called = true }
    assert_false called
  end

  test "on_mouse stores callback" do
    backend = RBGL::GUI::Backend.new(640, 480)
    called = false
    backend.on_mouse { called = true }
    assert_false called
  end

  test "on_resize stores callback" do
    backend = RBGL::GUI::Backend.new(640, 480)
    called = false
    backend.on_resize { called = true }
    assert_false called
  end
end

class TestableBackend < RBGL::GUI::Backend
  def emit_test_key(key, action)
    emit_key(key, action)
  end

  def emit_test_mouse(x, y, button, action)
    emit_mouse(x, y, button, action)
  end

  def emit_test_resize(width, height)
    emit_resize(width, height)
  end
end

class BackendCallbackTest < Test::Unit::TestCase
  test "dispatch_event routes key events" do
    backend = TestableBackend.new(640, 480)
    received = nil
    backend.on_key { |key, action| received = [key, action] }

    backend.dispatch_event(RBGL::GUI::Event.new(:key_press, key: 65))

    assert_equal [65, :press], received
  end

  test "dispatch_event routes resize events" do
    backend = TestableBackend.new(640, 480)
    received = nil
    backend.on_resize { |width, height| received = [width, height] }

    backend.dispatch_event(RBGL::GUI::Event.new(:resize, width: 800, height: 600))

    assert_equal [800, 600], received
  end

  test "emit_key calls key callback" do
    backend = TestableBackend.new(640, 480)
    received = nil
    backend.on_key { |key, action| received = [key, action] }
    backend.emit_test_key(65, :press)
    assert_equal [65, :press], received
  end

  test "emit_mouse calls mouse callback" do
    backend = TestableBackend.new(640, 480)
    received = nil
    backend.on_mouse { |x, y, button, action| received = [x, y, button, action] }
    backend.emit_test_mouse(100, 200, 1, :press)
    assert_equal [100, 200, 1, :press], received
  end

  test "emit_resize calls resize callback" do
    backend = TestableBackend.new(640, 480)
    received = nil
    backend.on_resize { |w, h| received = [w, h] }
    backend.emit_test_resize(800, 600)
    assert_equal [800, 600], received
  end

  test "emit_key does nothing without callback" do
    backend = TestableBackend.new(640, 480)
    backend.emit_test_key(65, :press)
  end
end
