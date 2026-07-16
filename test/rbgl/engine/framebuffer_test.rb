# frozen_string_literal: true

require_relative "../../test_helper"

class FramebufferTest < Test::Unit::TestCase
  test "builds a framebuffer from RGBA bytes" do
    framebuffer = RBGL::Engine::Framebuffer.from_rgba_bytes(2, 1, "\xFF\x00\x80\xFF\x00\xFF\x00\x40")

    assert_equal [255, 0, 128, 255, 0, 255, 0, 64], framebuffer.to_rgba_bytes.bytes
    assert_raise(FrozenError) { framebuffer.get_pixel(0, 0).r = 0.0 }
  end

  test "rejects malformed RGBA buffers" do
    error = assert_raise(ArgumentError) { RBGL::Engine::Framebuffer.from_rgba_bytes(2, 1, "short") }

    assert_includes error.message, "expected 8"
  end

  setup do
    @fb = RBGL::Engine::Framebuffer.new(10, 10)
  end

  test "initializes with width and height" do
    assert_equal 10, @fb.width
    assert_equal 10, @fb.height
  end

  test "color_buffer is initialized with black" do
    assert_equal 100, @fb.color_buffer.size
    assert_kind_of Larb::Color, @fb.color_buffer[0]
  end

  test "depth_buffer is initialized with infinity" do
    assert_equal 100, @fb.depth_buffer.size
    assert_equal Float::INFINITY, @fb.depth_buffer[0]
  end

  test "resize updates dimensions and clears buffers" do
    @fb.set_pixel(1, 1, Larb::Color.white)
    @fb.set_depth(1, 1, 0.5)

    @fb.resize(4, 3)

    assert_equal 4, @fb.width
    assert_equal 3, @fb.height
    assert_equal 12, @fb.color_buffer.size
    assert_equal 12, @fb.depth_buffer.size
    assert_equal Float::INFINITY, @fb.get_depth(0, 0)
    assert_equal 0.0, @fb.get_pixel(0, 0).r
  end

  test "get_pixel returns color at position" do
    color = @fb.get_pixel(0, 0)
    assert_kind_of Larb::Color, color
  end

  test "get_pixel returns nil for out of bounds" do
    assert_nil @fb.get_pixel(-1, 0)
    assert_nil @fb.get_pixel(0, -1)
    assert_nil @fb.get_pixel(10, 0)
    assert_nil @fb.get_pixel(0, 10)
  end

  test "set_pixel sets color at position" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    @fb.set_pixel(5, 5, red)
    assert_equal red.to_a, @fb.get_pixel(5, 5).to_a
  end

  test "set_pixel ignores out of bounds" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    @fb.set_pixel(-1, 0, red)
    @fb.set_pixel(10, 0, red)
  end

  test "get_depth returns depth at position" do
    assert_equal Float::INFINITY, @fb.get_depth(0, 0)
  end

  test "get_depth returns infinity for out of bounds" do
    assert_equal Float::INFINITY, @fb.get_depth(-1, 0)
    assert_equal Float::INFINITY, @fb.get_depth(10, 0)
  end

  test "set_depth sets depth at position" do
    @fb.set_depth(5, 5, 0.5)
    assert_equal 0.5, @fb.get_depth(5, 5)
  end

  test "set_depth ignores out of bounds" do
    @fb.set_depth(-1, 0, 0.5)
    @fb.set_depth(10, 0, 0.5)
  end

  test "write_pixel writes color and depth" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    result = @fb.write_pixel(5, 5, red, 0.5)
    assert_true result
    assert_equal red.to_a, @fb.get_pixel(5, 5).to_a
    assert_equal 0.5, @fb.get_depth(5, 5)
  end

  test "write_pixel respects depth test" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    blue = Larb::Color.new(0.0, 0.0, 1.0, 1.0)

    @fb.write_pixel(5, 5, red, 0.5)
    result = @fb.write_pixel(5, 5, blue, 0.6)
    assert_false result
    assert_equal red.to_a, @fb.get_pixel(5, 5).to_a
  end

  test "write_pixel can disable depth test" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    blue = Larb::Color.new(0.0, 0.0, 1.0, 1.0)

    @fb.write_pixel(5, 5, red, 0.5)
    result = @fb.write_pixel(5, 5, blue, 0.6, depth_test: false)
    assert_true result
    assert_equal blue.to_a, @fb.get_pixel(5, 5).to_a
  end

  test "write_pixel can disable depth write" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)

    result = @fb.write_pixel(5, 5, red, 0.5, depth_write: false)

    assert_true result
    assert_equal red.to_a, @fb.get_pixel(5, 5).to_a
    assert_equal Float::INFINITY, @fb.get_depth(5, 5)
  end

  test "write_pixel can alpha blend with existing color" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    blue = Larb::Color.new(0.0, 0.0, 1.0, 0.5)

    @fb.write_pixel(5, 5, red, 0.5)
    @fb.write_pixel(5, 5, blue, 0.4, blend_mode: :alpha)

    color = @fb.get_pixel(5, 5)
    assert_in_delta 0.5, color.r, 0.001
    assert_in_delta 0.0, color.g, 0.001
    assert_in_delta 0.5, color.b, 0.001
    assert_in_delta 1.0, color.a, 0.001
  end

  test "write_pixel returns false for out of bounds" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    assert_false @fb.write_pixel(-1, 0, red, 0.5)
    assert_false @fb.write_pixel(10, 0, red, 0.5)
  end

  test "clear resets color and depth buffers" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    @fb.set_pixel(5, 5, red)
    @fb.set_depth(5, 5, 0.5)

    @fb.clear

    assert_equal 0.0, @fb.get_pixel(5, 5).r
    assert_equal Float::INFINITY, @fb.get_depth(5, 5)
  end

  test "clear accepts custom color and depth" do
    white = Larb::Color.new(1.0, 1.0, 1.0, 1.0)
    @fb.clear(color: white, depth: 1.0)

    assert_equal 1.0, @fb.get_pixel(0, 0).r
    assert_equal 1.0, @fb.get_depth(0, 0)
  end

  test "clear safely shares immutable color objects" do
    red = Larb::Color.red
    @fb.clear(color: red)

    assert_raise(FrozenError) { @fb.get_pixel(0, 0).r = 0.25 }
    assert_same @fb.get_pixel(0, 0), @fb.get_pixel(1, 0)
    assert_not_same red, @fb.get_pixel(0, 0)
  end

  test "pixel writes do not retain caller-owned color objects" do
    color = Larb::Color.red
    @fb.set_pixel(0, 0, color)
    @fb.write_pixel(1, 0, color, 0.0)

    color.r = 0.25

    assert_in_delta 1.0, @fb.get_pixel(0, 0).r, 0.001
    assert_in_delta 1.0, @fb.get_pixel(1, 0).r, 0.001
    assert_true @fb.get_pixel(0, 0).frozen?
    assert_true @fb.get_pixel(1, 0).frozen?
  end

  test "clear_color only clears color buffer" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    @fb.set_depth(5, 5, 0.5)
    @fb.clear_color(red)

    assert_equal 1.0, @fb.get_pixel(0, 0).r
    assert_equal 0.5, @fb.get_depth(5, 5)
  end

  test "clear_depth only clears depth buffer" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    @fb.set_pixel(5, 5, red)
    @fb.clear_depth(1.0)

    assert_equal 1.0, @fb.get_pixel(5, 5).r
    assert_equal 1.0, @fb.get_depth(0, 0)
  end

  test "to_ppm generates valid PPM header" do
    ppm = @fb.to_ppm
    lines = ppm.lines
    assert_equal "P3\n", lines[0]
    assert_equal "10 10\n", lines[1]
    assert_equal "255\n", lines[2]
  end

  test "to_ppm_binary generates valid binary PPM" do
    ppm = @fb.to_ppm_binary
    assert ppm.start_with?("P6\n10 10\n255\n")
  end

  test "to_rgba_bytes generates RGBA byte array" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 0.5)
    @fb.set_pixel(0, 0, red)
    bytes = @fb.to_rgba_bytes
    unpacked = bytes.unpack("C*")

    assert_equal 400, bytes.bytesize
    assert_equal [255, 0, 0, 128], unpacked[0, 4]
  end

  test "to_bgra_bytes generates BGRA byte array" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    @fb.set_pixel(0, 0, red)
    bytes = @fb.to_bgra_bytes.unpack("C*")

    # BGRA format: B=0, G=0, R=255, A=255
    assert_equal 0, bytes[0]
    assert_equal 0, bytes[1]
    assert_equal 255, bytes[2]
    assert_equal 255, bytes[3]
  end
end
