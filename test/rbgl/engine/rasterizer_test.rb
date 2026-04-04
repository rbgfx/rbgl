# frozen_string_literal: true

require_relative "../../test_helper"

class RasterizerTest < Test::Unit::TestCase
  setup do
    @fb = RBGL::Engine::Framebuffer.new(100, 100)
    @rasterizer = RBGL::Engine::Rasterizer.new(@fb)
    @fragment_shader = RBGL::Engine::FragmentShader.new do |_input, _uniforms, output|
      output.color = Larb::Color.new(1, 0, 0, 1)
    end
    @uniforms = RBGL::Engine::Uniforms.new
  end

  test "initializes with framebuffer and viewport" do
    assert_equal({ x: 0, y: 0, width: 100, height: 100 }, @rasterizer.viewport)
  end

  test "viewport can be changed" do
    @rasterizer.viewport = { x: 10, y: 10, width: 80, height: 80 }
    assert_equal 10, @rasterizer.viewport[:x]
  end

  test "rasterize_triangle draws triangle" do
    v0 = create_vertex(0.0, 0.5, 0.0)
    v1 = create_vertex(-0.5, -0.5, 0.0)
    v2 = create_vertex(0.5, -0.5, 0.0)

    @rasterizer.rasterize_triangle(v0, v1, v2, @fragment_shader, @uniforms)

    center_color = @fb.get_pixel(50, 50)
    assert_equal 1.0, center_color.r
  end

  test "rasterize_triangle respects back face culling" do
    v0 = create_vertex(0.0, 0.5, 0.0)
    v1 = create_vertex(0.5, -0.5, 0.0)
    v2 = create_vertex(-0.5, -0.5, 0.0)

    @rasterizer.rasterize_triangle(v0, v1, v2, @fragment_shader, @uniforms, cull_mode: :back)

    center_color = @fb.get_pixel(50, 50)
    assert_equal 0.0, center_color.r
  end

  test "rasterize_triangle respects front face culling" do
    v0 = create_vertex(0.0, 0.5, 0.0)
    v1 = create_vertex(-0.5, -0.5, 0.0)
    v2 = create_vertex(0.5, -0.5, 0.0)

    @rasterizer.rasterize_triangle(v0, v1, v2, @fragment_shader, @uniforms, cull_mode: :front)

    center_color = @fb.get_pixel(50, 50)
    assert_equal 0.0, center_color.r
  end

  test "rasterize_triangle with no culling" do
    v0 = create_vertex(0.0, 0.5, 0.0)
    v1 = create_vertex(0.5, -0.5, 0.0)
    v2 = create_vertex(-0.5, -0.5, 0.0)

    @rasterizer.rasterize_triangle(v0, v1, v2, @fragment_shader, @uniforms, cull_mode: :none)

    center_color = @fb.get_pixel(50, 50)
    assert_equal 1.0, center_color.r
  end

  test "rasterize_triangle skips degenerate triangles" do
    v0 = create_vertex(0.0, 0.0, 0.0)
    v1 = create_vertex(0.0, 0.0, 0.0)
    v2 = create_vertex(0.0, 0.0, 0.0)

    @rasterizer.rasterize_triangle(v0, v1, v2, @fragment_shader, @uniforms)
  end

  test "rasterize_line draws line" do
    v0 = create_vertex(-0.5, 0.0, 0.0)
    v1 = create_vertex(0.5, 0.0, 0.0)

    @rasterizer.rasterize_line(v0, v1, @fragment_shader, @uniforms)

    middle_color = @fb.get_pixel(50, 50)
    assert_equal 1.0, middle_color.r
  end

  test "rasterize_point draws point" do
    v = create_vertex(0.0, 0.0, 0.0)

    @rasterizer.rasterize_point(v, @fragment_shader, @uniforms)

    center_color = @fb.get_pixel(50, 50)
    assert_equal 1.0, center_color.r
  end

  test "rasterize_point with size draws larger point" do
    v = create_vertex(0.0, 0.0, 0.0)

    @rasterizer.rasterize_point(v, @fragment_shader, @uniforms, size: 5)
  end

  test "interpolate_value handles supported attribute types" do
    vec2 = @rasterizer.send(
      :interpolate_value,
      Larb::Vec2.new(0.0, 1.0),
      Larb::Vec2.new(2.0, 3.0),
      Larb::Vec2.new(4.0, 5.0),
      0.25, 0.25, 0.5
    )
    vec3 = @rasterizer.send(
      :interpolate_value,
      Larb::Vec3.new(0.0, 1.0, 2.0),
      Larb::Vec3.new(2.0, 3.0, 4.0),
      Larb::Vec3.new(4.0, 5.0, 6.0),
      0.25, 0.25, 0.5
    )
    vec4 = @rasterizer.send(
      :interpolate_value,
      Larb::Vec4.new(0.0, 1.0, 2.0, 3.0),
      Larb::Vec4.new(2.0, 3.0, 4.0, 5.0),
      Larb::Vec4.new(4.0, 5.0, 6.0, 7.0),
      0.25, 0.25, 0.5
    )
    numeric = @rasterizer.send(:interpolate_value, 1.0, 3.0, 5.0, 0.25, 0.25, 0.5)
    passthrough = Object.new
    same_object = @rasterizer.send(:interpolate_value, passthrough, Object.new, Object.new, 0.25, 0.25, 0.5)

    assert_kind_of Larb::Vec2, vec2
    assert_in_delta 2.5, vec2.x, 0.001
    assert_kind_of Larb::Vec3, vec3
    assert_in_delta 4.5, vec3.z, 0.001
    assert_kind_of Larb::Vec4, vec4
    assert_in_delta 5.5, vec4.w, 0.001
    assert_in_delta 3.5, numeric, 0.001
    assert_same passthrough, same_object
  end

  test "interpolate_line_attributes handles numeric and passthrough values" do
    v0 = RBGL::Engine::ShaderIO.new
    v0[:position] = Larb::Vec4.new(-0.5, 0.0, 0.0, 1.0)
    v0[:weight] = 1.0
    v0[:tag] = :start

    v1 = RBGL::Engine::ShaderIO.new
    v1[:position] = Larb::Vec4.new(0.5, 0.0, 0.0, 1.0)
    v1[:weight] = 3.0
    v1[:tag] = :finish

    result = @rasterizer.send(:interpolate_line_attributes, v0, v1, 0.25)

    assert_in_delta 1.5, result[:weight], 0.001
    assert_equal :start, result[:tag]
  end

  test "interpolate_line_attributes handles vector and color values" do
    v0 = RBGL::Engine::ShaderIO.new
    v0[:position] = Larb::Vec4.new(-0.5, 0.0, 0.0, 1.0)
    v0[:uv] = Larb::Vec2.new(0.0, 1.0)
    v0[:color] = Larb::Color.new(1.0, 0.0, 0.0, 1.0)

    v1 = RBGL::Engine::ShaderIO.new
    v1[:position] = Larb::Vec4.new(0.5, 0.0, 0.0, 1.0)
    v1[:uv] = Larb::Vec2.new(1.0, 0.0)
    v1[:color] = Larb::Color.new(0.0, 0.0, 1.0, 0.5)

    result = @rasterizer.send(:interpolate_line_attributes, v0, v1, 0.25)

    assert_in_delta 0.25, result[:uv].x, 0.001
    assert_in_delta 0.75, result[:uv].y, 0.001
    assert_in_delta 0.75, result[:color].r, 0.001
    assert_in_delta 0.25, result[:color].b, 0.001
    assert_in_delta 0.875, result[:color].a, 0.001
  end

  test "perspective_correct_weights adjusts weights by clip w" do
    positions = [
      Larb::Vec4.new(0.0, 0.0, 0.0, 1.0),
      Larb::Vec4.new(0.0, 0.0, 0.0, 2.0),
      Larb::Vec4.new(0.0, 0.0, 0.0, 4.0)
    ]

    weights = @rasterizer.send(:perspective_correct_weights, positions, [0.25, 0.25, 0.5])

    assert_in_delta 0.5, weights[0], 0.001
    assert_in_delta 0.25, weights[1], 0.001
    assert_in_delta 0.25, weights[2], 0.001
  end

  test "interpolate_line_attributes uses perspective corrected weights" do
    v0 = RBGL::Engine::ShaderIO.new
    v0[:position] = Larb::Vec4.new(-0.5, 0.0, 0.0, 1.0)
    v0[:weight] = 0.0

    v1 = RBGL::Engine::ShaderIO.new
    v1[:position] = Larb::Vec4.new(0.5, 0.0, 0.0, 2.0)
    v1[:weight] = 1.0

    result = @rasterizer.send(:interpolate_line_attributes, v0, v1, 0.5)

    assert_in_delta(1.0 / 3.0, result[:weight], 0.001)
  end

  private

  def create_vertex(x, y, z)
    io = RBGL::Engine::ShaderIO.new
    io[:position] = Larb::Vec4.new(x, y, z, 1.0)
    io[:color] = Larb::Color.new(1, 1, 1, 1)
    io
  end
end
