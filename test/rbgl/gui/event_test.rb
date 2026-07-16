# frozen_string_literal: true

require_relative "../../test_helper"

class EventTest < Test::Unit::TestCase
  test "initializes with type and data" do
    event = RBGL::GUI::Event.new(:key_press, key: 65, char: "a")
    assert_equal :key_press, event.type
    assert_equal 65, event.data[:key]
  end

  test "accesses data via brackets" do
    event = RBGL::GUI::Event.new(:mouse_move, x: 100, y: 200)
    assert_equal 100, event[:x]
    assert_equal 200, event[:y]
  end

  test "accesses data via method_missing" do
    event = RBGL::GUI::Event.new(:key_press, key: 65, char: "a")
    assert_equal 65, event.key
    assert_equal "a", event.char
  end

  test "does not ignore arguments passed to data accessors" do
    event = RBGL::GUI::Event.new(:mouse_move, x: 100)

    assert_raise(NoMethodError) { event.x(999) }
  end

  test "respond_to_missing returns true for data keys" do
    event = RBGL::GUI::Event.new(:key_press, key: 65)
    assert event.respond_to?(:key)
  end

  test "respond_to_missing returns false for unknown keys" do
    event = RBGL::GUI::Event.new(:key_press, key: 65)
    assert_false event.respond_to?(:unknown)
  end

  test "to_h returns hash with type and data" do
    event = RBGL::GUI::Event.new(:mouse_press, x: 50, y: 60, button: 1)
    h = event.to_h
    assert_equal :mouse_press, h[:type]
    assert_equal 50, h[:x]
    assert_equal 60, h[:y]
    assert_equal 1, h[:button]
  end

  test "inspect returns readable string" do
    event = RBGL::GUI::Event.new(:key_press, key: 65)
    str = event.inspect
    assert str.include?("key_press")
    assert str.include?("key: 65")
  end
end
