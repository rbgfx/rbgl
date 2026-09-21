# frozen_string_literal: true

require_relative "../../test_helper"
require "rbgl/gui/cocoa/backend"

class CocoaBackendTest < Test::Unit::TestCase
  test "metaco availability constant is namespaced" do
    assert RBGL::GUI::Cocoa.const_defined?(:METACO_AVAILABLE)
  end

  test "present returns false when no handle is available" do
    backend = RBGL::GUI::Cocoa::Backend.allocate

    assert_false backend.present(RBGL::Engine::Framebuffer.new(1, 1))
  end

  test "backend without a handle is closed" do
    backend = RBGL::GUI::Cocoa::Backend.allocate

    assert_true backend.should_close?
  end

  test "convert_event maps resize events" do
    backend = RBGL::GUI::Cocoa::Backend.allocate

    event = backend.send(:convert_event, { type: :resize, width: 640, height: 480 })

    assert_equal :resize, event.type
    assert_equal 640, event.width
    assert_equal 480, event.height
  end

  test "convert_event preserves scroll, modifier, and focus events" do
    backend = RBGL::GUI::Cocoa::Backend.allocate
    scroll = backend.send(:convert_event, type: :scroll, dx: 1.5, dy: -2.0, modifiers: [:shift])
    click = backend.send(:convert_event, type: :mouse_press, x: 4, y: 5, button: 0, modifiers: [:command])

    assert_equal [1.5, -2.0, [:shift]], [scroll.dx, scroll.dy, scroll.modifiers]
    assert_equal [:command], click.modifiers
    assert_equal :focus, backend.send(:convert_event, type: :focus).type
    assert_equal :blur, backend.send(:convert_event, type: :blur).type
  end

  test "converts Cocoa bottom-left mouse coordinates to portable top-left coordinates" do
    backend = RBGL::GUI::Cocoa::Backend.allocate
    backend.instance_variable_set(:@height, 100)
    event = backend.send(:convert_event, type: :mouse_move, x: 4.0, y: 9.0)

    assert_equal 90.0, event.y
  end

  test "convert_event normalizes Cocoa key codes" do
    backend = RBGL::GUI::Cocoa::Backend.allocate

    q_event = backend.send(:convert_event, { type: :key_press, key: 12, char: "q" })
    escape_event = backend.send(:convert_event, { type: :key_release, key: 53 })

    assert_equal :q, q_event.key
    assert_equal 12, q_event.keycode
    assert_equal :escape, escape_event.key
  end

  test "key mapper handles characterless key releases" do
    backend = RBGL::GUI::Cocoa::Backend.allocate

    events = {
      0 => :a,
      36 => :enter,
      49 => :space,
      56 => :left_shift,
      115 => :home,
      123 => :left,
      126 => :up
    }.map do |keycode, key|
      [backend.send(:convert_event, { type: :key_release, key: keycode }), key]
    end

    events.each { |event, key| assert_equal key, event.key }
  end

  test "key mapper preserves unknown Cocoa key codes" do
    assert_equal 999, RBGL::GUI::Cocoa::KeyMapper.key(999)
  end
end
