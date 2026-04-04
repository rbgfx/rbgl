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

  test "initialization rejects data with unexpected size" do
    assert_raise(ArgumentError) do
      RBGL::Engine::Texture.new(2, 2, [Larb::Color.black])
    end
  end

  test "initialization rejects data with unsupported pixel types" do
    bad_pixels = Array.new(4, :red)

    assert_raise(ArgumentError) do
      RBGL::Engine::Texture.new(2, 2, bad_pixels)
    end
  end

  test "initialization rejects non enumerable data" do
    assert_raise(ArgumentError) do
      RBGL::Engine::Texture.new(2, 2, 123)
    end
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

  test "wrap setters reject unsupported modes" do
    assert_raise(ArgumentError) { @tex.wrap_s = :invalid }
    assert_raise(ArgumentError) { @tex.wrap_t = :invalid }
  end

  test "filter setters reject unsupported modes" do
    assert_raise(ArgumentError) { @tex.filter_min = :invalid }
    assert_raise(ArgumentError) { @tex.filter_mag = :invalid }
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

  test "positive lod samples generated mip levels" do
    tex = RBGL::Engine::Texture.new(4, 4)
    white = Larb::Color.rgb(1.0, 1.0, 1.0)
    black = Larb::Color.rgb(0.0, 0.0, 0.0)

    4.times do |y|
      4.times do |x|
        tex.set_pixel(x, y, (x + y).even? ? white : black)
      end
    end

    tex.filter_min = :nearest

    color = tex.sample(0.125, 0.125, lod: 1)

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
        # comment
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

  test "from_ppm loads binary P6 files" do
    Dir.mktmpdir do |tmpdir|
      ppm_file = File.join(tmpdir, "test_binary.ppm")
      header = "P6\n2 2\n255\n"
      pixels = [
        255, 0, 0,
        0, 255, 0,
        0, 0, 255,
        255, 255, 255
      ].pack("C*")
      File.binwrite(ppm_file, header + pixels)

      tex = RBGL::Engine::Texture.from_ppm(ppm_file)

      assert_equal 2, tex.width
      assert_equal 2, tex.height
      assert_equal 4, tex.data.size

      green_pixel = tex.get_pixel(1, 0)
      assert_in_delta 0.0, green_pixel.r, 0.01
      assert_in_delta 1.0, green_pixel.g, 0.01
      assert_in_delta 0.0, green_pixel.b, 0.01
    end
  end

  test "from_ppm rejects max values above 65535" do
    Dir.mktmpdir do |tmpdir|
      ppm_file = File.join(tmpdir, "bad.ppm")
      ppm_content = <<~PPM
        P3
        1 1
        70000
        0 0 0
      PPM
      File.write(ppm_file, ppm_content)

      assert_raise(ArgumentError) do
        RBGL::Engine::Texture.from_ppm(ppm_file)
      end
    end
  end
end
