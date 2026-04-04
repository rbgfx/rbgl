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

  test "convert_event maps resize events" do
    backend = RBGL::GUI::Cocoa::Backend.allocate

    event = backend.send(:convert_event, { type: :resize, width: 640, height: 480 })

    assert_equal :resize, event.type
    assert_equal 640, event.width
    assert_equal 480, event.height
  end
end
