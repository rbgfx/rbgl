# frozen_string_literal: true

require_relative "../../test_helper"
require "tmpdir"

class TextureTest < Test::Unit::TestCase
  setup do
    @tex = RBGL::Engine::Texture.new(4, 4)
  end

  test "initializes with width and height" do
    assert_equal 4, @tex.width
    assert_equal 4, @tex.height
  end

  test "data is initialized with black" do
    assert_equal 16, @tex.data.size
    assert_kind_of Larb::Color, @tex.data[0]
  end

  test "default wrap modes are repeat" do
    assert_equal :repeat, @tex.wrap_s
    assert_equal :repeat, @tex.wrap_t
  end

  test "default filter modes are linear" do
    assert_equal :linear, @tex.filter_min
    assert_equal :linear, @tex.filter_mag
  end

  test "get_pixel returns pixel at position" do
    color = @tex.get_pixel(0, 0)
    assert_kind_of Larb::Color, color
  end

  test "get_pixel clamps out of bounds" do
    color = @tex.get_pixel(-1, -1)
    assert_kind_of Larb::Color, color
    color = @tex.get_pixel(100, 100)
    assert_kind_of Larb::Color, color
  end

  test "set_pixel sets pixel at position" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    @tex.set_pixel(2, 2, red)
    assert_equal red, @tex.get_pixel(2, 2)
  end

  test "set_pixel ignores out of bounds" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    @tex.set_pixel(-1, 0, red)
    @tex.set_pixel(0, -1, red)
    @tex.set_pixel(4, 0, red)
    @tex.set_pixel(0, 4, red)
  end

  test "sample returns color at UV" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    @tex.set_pixel(0, 0, red)
    @tex.filter_mag = :nearest

    color = @tex.sample(0.0, 0.0)
    assert_kind_of Larb::Color, color
  end

  test "sample with repeat wrap" do
    @tex.wrap_s = :repeat
    color = @tex.sample(1.5, 0.5)
    assert_kind_of Larb::Color, color
  end

  test "sample with clamp wrap" do
    @tex.wrap_s = :clamp
    color = @tex.sample(1.5, 0.5)
    assert_kind_of Larb::Color, color
  end

  test "sample with mirror wrap" do
    @tex.wrap_s = :mirror
    color = @tex.sample(1.5, 0.5)
    assert_kind_of Larb::Color, color
  end

  test "sample with nearest filter" do
    @tex.filter_mag = :nearest
    color = @tex.sample(0.25, 0.25)
    assert_kind_of Larb::Color, color
  end

  test "sample with linear filter" do
    @tex.filter_mag = :linear
    color = @tex.sample(0.25, 0.25)
    assert_kind_of Larb::Color, color
  end

  test "sample uses magnification filter when lod is zero" do
    tex = RBGL::Engine::Texture.new(2, 2)
    tex.set_pixel(0, 0, Larb::Color.rgb(1.0, 0.0, 0.0))
    tex.set_pixel(1, 0, Larb::Color.rgb(0.0, 1.0, 0.0))
    tex.set_pixel(0, 1, Larb::Color.rgb(0.0, 0.0, 1.0))
    tex.set_pixel(1, 1, Larb::Color.rgb(1.0, 1.0, 1.0))
    tex.filter_mag = :nearest
    tex.filter_min = :linear

    color = tex.sample(0.5, 0.5, lod: 0)

    assert_in_delta 1.0, color.r, 0.001
    assert_in_delta 1.0, color.g, 0.001
    assert_in_delta 1.0, color.b, 0.001
  end

  test "sample uses minification filter when lod is positive" do
    tex = RBGL::Engine::Texture.new(2, 2)
    tex.set_pixel(0, 0, Larb::Color.rgb(1.0, 0.0, 0.0))
    tex.set_pixel(1, 0, Larb::Color.rgb(0.0, 1.0, 0.0))
    tex.set_pixel(0, 1, Larb::Color.rgb(0.0, 0.0, 1.0))
    tex.set_pixel(1, 1, Larb::Color.rgb(1.0, 1.0, 1.0))
    tex.filter_mag = :nearest
    tex.filter_min = :linear

    color = tex.sample(0.5, 0.5, lod: 1)

    assert_in_delta 0.5, color.r, 0.001
    assert_in_delta 0.5, color.g, 0.001
    assert_in_delta 0.5, color.b, 0.001
  end

  test "checker creates checkerboard texture" do
    tex = RBGL::Engine::Texture.checker(8, 8, 2)
    assert_equal 8, tex.width
    assert_equal 8, tex.height
  end

  test "solid creates solid color texture" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    tex = RBGL::Engine::Texture.solid(4, 4, red)
    assert_equal red, tex.get_pixel(2, 2)
  end

  test "WRAP constants are defined" do
    assert_equal :repeat, RBGL::Engine::Texture::WRAP_REPEAT
    assert_equal :clamp, RBGL::Engine::Texture::WRAP_CLAMP
    assert_equal :mirror, RBGL::Engine::Texture::WRAP_MIRROR
  end

  test "FILTER constants are defined" do
    assert_equal :nearest, RBGL::Engine::Texture::FILTER_NEAREST
    assert_equal :linear, RBGL::Engine::Texture::FILTER_LINEAR
  end

  test "from_ppm loads PPM file" do
    Dir.mktmpdir do |tmpdir|
      ppm_file = File.join(tmpdir, "test.ppm")
      ppm_content = <<~PPM
        P3
        2 2
        255
        255 0 0
        0 255 0
        0 0 255
        255 255 255
      PPM
      File.write(ppm_file, ppm_content)

      tex = RBGL::Engine::Texture.from_ppm(ppm_file)
      assert_equal 2, tex.width
      assert_equal 2, tex.height
      assert_equal 4, tex.data.size

      # Check pixel colors
      red_pixel = tex.get_pixel(0, 0)
      assert_in_delta 1.0, red_pixel.r, 0.01
      assert_in_delta 0.0, red_pixel.g, 0.01
      assert_in_delta 0.0, red_pixel.b, 0.01
    end
  end
end
